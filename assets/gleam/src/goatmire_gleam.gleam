import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

/// Lustre app constructor used by `GoatmireWeb.GleamSocket` via
/// `:lustre.start_server_component/2`. Runs on the Erlang target (BEAM).
pub fn component() -> lustre.App(Nil, Model, Msg) {
  lustre.application(init, update, view)
}

// ---------------------------------------------------------------------------
// Domain
// ---------------------------------------------------------------------------

pub type Post {
  Post(id: String, title: String, body: String)
}

pub type Author {
  Author(id: String, name: String, posts: List(Post))
}

pub type Model {
  Model(
    authors: List(Author),
    author_name: String,
    post_author_id: String,
    post_title: String,
    post_body: String,
    flash: Option(String),
    error: Option(String),
    loading: Bool,
  )
}

pub type Msg {
  AuthorsLoaded(Result(List(Author), String))
  AuthorNameChanged(String)
  PostAuthorChanged(String)
  PostTitleChanged(String)
  PostBodyChanged(String)
  SubmitAuthor(List(#(String, String)))
  SubmitPost(List(#(String, String)))
  AuthorCreateFinished(Result(Author, String))
  PostCreateFinished(Result(Post, String))
  /// Dispatched from Elixir when Ash PubSub fires (multi-tab sync).
  BlogChanged
}

// ---------------------------------------------------------------------------
// Init / update
// ---------------------------------------------------------------------------

fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      authors: [],
      author_name: "",
      post_author_id: "",
      post_title: "",
      post_body: "",
      flash: None,
      error: None,
      loading: True,
    )

  #(model, reload_authors())
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    AuthorsLoaded(Ok(authors)) -> #(
      Model(..model, authors:, loading: False, error: None),
      effect.none(),
    )

    AuthorsLoaded(Error(message)) -> #(
      Model(..model, loading: False, error: Some(message)),
      effect.none(),
    )

    AuthorNameChanged(author_name) -> #(
      Model(..model, author_name:),
      effect.none(),
    )

    PostAuthorChanged(post_author_id) -> #(
      Model(..model, post_author_id:),
      effect.none(),
    )

    PostTitleChanged(post_title) -> #(Model(..model, post_title:), effect.none())

    PostBodyChanged(post_body) -> #(Model(..model, post_body:), effect.none())

    SubmitAuthor(fields) -> {
      let name =
        form_value(fields, "name")
        |> fallback_nonempty(model.author_name)
        |> string.trim

      case name {
        "" -> #(
          Model(..model, error: Some("Name is required."), flash: None),
          effect.none(),
        )
        _ -> #(
          Model(..model, author_name: name, flash: None, error: None),
          create_author_effect(name),
        )
      }
    }

    SubmitPost(fields) -> {
      let author_id =
        form_value(fields, "author_id")
        |> fallback_nonempty(model.post_author_id)
      let title =
        form_value(fields, "title")
        |> fallback_nonempty(model.post_title)
        |> string.trim
      let body =
        form_value(fields, "body")
        |> fallback_nonempty(model.post_body)

      case author_id, title {
        "", _ -> #(
          Model(..model, error: Some("Choose an author."), flash: None),
          effect.none(),
        )
        _, "" -> #(
          Model(..model, error: Some("Title is required."), flash: None),
          effect.none(),
        )
        _, _ -> #(
          Model(
            ..model,
            post_author_id: author_id,
            post_title: title,
            post_body: body,
            flash: None,
            error: None,
          ),
          create_post_effect(author_id, title, body),
        )
      }
    }

    AuthorCreateFinished(Ok(author)) -> #(
      Model(
        ..model,
        author_name: "",
        flash: Some(
          "Created author “"
          <> author.name
          <> "”. Open another tab to see it appear live.",
        ),
        error: None,
      ),
      reload_authors(),
    )

    AuthorCreateFinished(Error(message)) -> #(
      Model(..model, error: Some(message), flash: None),
      effect.none(),
    )

    PostCreateFinished(Ok(post)) -> #(
      Model(
        ..model,
        post_title: "",
        post_body: "",
        flash: Some("Created post “" <> post.title <> "”."),
        error: None,
      ),
      reload_authors(),
    )

    PostCreateFinished(Error(message)) -> #(
      Model(..model, error: Some(message), flash: None),
      effect.none(),
    )

    BlogChanged -> #(model, reload_authors())
  }
}

// ---------------------------------------------------------------------------
// In-process Ash effects (Elixir façade)
// ---------------------------------------------------------------------------

fn reload_authors() -> Effect(Msg) {
  effect.from(fn(dispatch) { dispatch(AuthorsLoaded(list_authors())) })
}

fn create_author_effect(name: String) -> Effect(Msg) {
  effect.from(fn(dispatch) { dispatch(AuthorCreateFinished(create_author(name))) })
}

fn create_post_effect(author_id: String, title: String, body: String) -> Effect(
  Msg,
) {
  effect.from(fn(dispatch) {
    dispatch(PostCreateFinished(create_post(author_id, title, body)))
  })
}

@external(erlang, "Elixir.Goatmire.Blog.GleamFacade", "list_authors")
fn list_authors_raw() -> Dynamic

@external(erlang, "Elixir.Goatmire.Blog.GleamFacade", "create_author")
fn create_author_raw(name: String) -> Result(Dynamic, String)

@external(erlang, "Elixir.Goatmire.Blog.GleamFacade", "create_post")
fn create_post_raw(
  author_id: String,
  title: String,
  body: String,
) -> Result(Dynamic, String)

fn list_authors() -> Result(List(Author), String) {
  case decode.run(list_authors_raw(), decode.list(author_decoder())) {
    Ok(authors) -> Ok(authors)
    Error(_) -> Error("Could not decode authors from Ash façade")
  }
}

fn create_author(name: String) -> Result(Author, String) {
  case create_author_raw(name) {
    Ok(dyn) ->
      decode.run(dyn, author_decoder())
      |> result.map_error(fn(_) { "Could not decode created author" })
    Error(message) -> Error(message)
  }
}

fn create_post(
  author_id: String,
  title: String,
  body: String,
) -> Result(Post, String) {
  case create_post_raw(author_id, title, body) {
    Ok(dyn) ->
      decode.run(dyn, post_decoder())
      |> result.map_error(fn(_) { "Could not decode created post" })
    Error(message) -> Error(message)
  }
}

fn author_decoder() -> decode.Decoder(Author) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use posts <- decode.field("posts", decode.list(post_decoder()))
  decode.success(Author(id:, name:, posts:))
}

fn post_decoder() -> decode.Decoder(Post) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use body <- decode.optional_field("body", "", decode.string)
  decode.success(Post(id:, title:, body:))
}

fn form_value(fields: List(#(String, String)), key: String) -> String {
  case list.find(fields, fn(pair) { pair.0 == key }) {
    Ok(#(_, value)) -> value
    Error(_) -> ""
  }
}

fn fallback_nonempty(value: String, fallback: String) -> String {
  case string.trim(value) {
    "" -> fallback
    trimmed -> trimmed
  }
}

// ---------------------------------------------------------------------------
// View
// ---------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("mx-auto max-w-3xl space-y-10")], [
    header_section(),
    flash_section(model),
    create_author_section(model),
    create_post_section(model),
    authors_list_section(model),
    footer_section(),
  ])
}

fn header_section() -> Element(Msg) {
  html.header([attribute.class("space-y-2")], [
    html.p(
      [attribute.class("text-sm uppercase tracking-wide text-base-content/60")],
      [html.text("Ash + Gleam/Lustre server component")],
    ),
    html.h1([attribute.class("text-3xl font-bold")], [
      html.text("Goatmire Blog"),
    ]),
    html.p([attribute.class("text-base-content/80")], [
      html.text(
        "Same domain as LiveView and Hologram: create an Author, then add Posts. Gleam runs on the BEAM as a Lustre server component and calls Ash in-process. Open two tabs — changes sync via Ash PubSub.",
      ),
    ]),
  ])
}

fn flash_section(model: Model) -> Element(Msg) {
  html.div([], [
    case model.flash {
      Some(message) ->
        html.div(
          [
            attribute.class("rounded-lg bg-success/20 px-4 py-3 text-sm"),
            attribute.role("status"),
          ],
          [html.text(message)],
        )
      None -> element.none()
    },
    case model.error {
      Some(message) ->
        html.div(
          [
            attribute.class("rounded-lg bg-error/20 px-4 py-3 text-sm"),
            attribute.role("alert"),
          ],
          [html.text(message)],
        )
      None -> element.none()
    },
    case model.loading {
      True ->
        html.p([attribute.class("text-sm text-base-content/60")], [
          html.text("Loading authors…"),
        ])
      False -> element.none()
    },
  ])
}

fn create_author_section(model: Model) -> Element(Msg) {
  html.section([attribute.class("space-y-4"), attribute.id("create-author")], [
    html.h2([attribute.class("text-xl font-semibold")], [
      html.text("1. Create an author"),
    ]),
    html.p([attribute.class("text-sm text-base-content/70")], [
      html.text("Start here if the list below is empty."),
    ]),
    html.form(
      [
        attribute.id("author-form"),
        attribute.class("flex flex-wrap gap-3 items-end"),
        event.on_submit(SubmitAuthor),
      ],
      [
        html.div([attribute.class("grow min-w-48")], [
          html.label(
            [attribute.class("label py-1"), attribute.for("gleam_author_name")],
            [html.text("Name")],
          ),
          html.input([
            attribute.id("gleam_author_name"),
            attribute.type_("text"),
            attribute.name("name"),
            attribute.value(model.author_name),
            attribute.placeholder("e.g. Ada Lovelace"),
            attribute.class("input input-bordered w-full"),
            attribute.required(True),
            event.on_input(AuthorNameChanged),
          ]),
        ]),
        html.button(
          [attribute.type_("submit"), attribute.class("btn btn-primary")],
          [html.text("Add author")],
        ),
      ],
    ),
  ])
}

fn create_post_section(model: Model) -> Element(Msg) {
  html.section([attribute.class("space-y-4"), attribute.id("create-post")], [
    html.h2([attribute.class("text-xl font-semibold")], [
      html.text("2. Create a post"),
    ]),
    case model.authors {
      [] ->
        html.p([attribute.class("rounded-lg bg-warning/20 px-4 py-3 text-sm")], [
          html.text(
            "No authors yet — add one above, then you can attach posts here.",
          ),
        ])
      authors ->
        html.form(
          [
            attribute.id("post-form"),
            attribute.class("space-y-3"),
            event.on_submit(SubmitPost),
          ],
          [
            html.div([], [
              html.label(
                [
                  attribute.class("label py-1"),
                  attribute.for("gleam_post_author_id"),
                ],
                [html.text("Author")],
              ),
              html.select(
                [
                  attribute.id("gleam_post_author_id"),
                  attribute.name("author_id"),
                  attribute.class("select select-bordered w-full"),
                  attribute.required(True),
                  event.on_change(PostAuthorChanged),
                ],
                list.append(
                  [html.option([attribute.value("")], "Choose an author…")],
                  list.map(authors, fn(author) {
                    html.option(
                      [
                        attribute.value(author.id),
                        attribute.selected(author.id == model.post_author_id),
                      ],
                      author.name,
                    )
                  }),
                ),
              ),
            ]),
            html.div([], [
              html.label(
                [attribute.class("label py-1"), attribute.for("gleam_post_title")],
                [html.text("Title")],
              ),
              html.input([
                attribute.id("gleam_post_title"),
                attribute.type_("text"),
                attribute.name("title"),
                attribute.value(model.post_title),
                attribute.placeholder("Post title"),
                attribute.class("input input-bordered w-full"),
                attribute.required(True),
                event.on_input(PostTitleChanged),
              ]),
            ]),
            html.div([], [
              html.label(
                [attribute.class("label py-1"), attribute.for("gleam_post_body")],
                [html.text("Body")],
              ),
              html.textarea(
                [
                  attribute.id("gleam_post_body"),
                  attribute.name("body"),
                  attribute.rows(3),
                  attribute.placeholder("A short note…"),
                  attribute.class("textarea textarea-bordered w-full"),
                  event.on_input(PostBodyChanged),
                ],
                model.post_body,
              ),
            ]),
            html.button(
              [attribute.type_("submit"), attribute.class("btn btn-secondary")],
              [html.text("Add post")],
            ),
          ],
        )
    },
  ])
}

fn authors_list_section(model: Model) -> Element(Msg) {
  html.section([attribute.class("space-y-4"), attribute.id("authors-list")], [
    html.h2([attribute.class("text-xl font-semibold")], [
      html.text("Authors & posts"),
    ]),
    case model.authors {
      [] ->
        html.p(
          [
            attribute.class(
              "rounded-lg border border-dashed border-base-300 px-4 py-8 text-center text-base-content/70",
            ),
          ],
          [
            html.text(
              "Empty state: click Add author above to seed your first record.",
            ),
          ],
        )
      authors ->
        html.ul([attribute.class("space-y-6")], list.map(authors, author_item))
    },
  ])
}

fn author_item(author: Author) -> Element(Msg) {
  html.li(
    [
      attribute.class("border-b border-base-300 pb-4"),
      attribute.id("author-" <> author.id),
    ],
    [
      html.h3([attribute.class("text-lg font-medium")], [html.text(author.name)]),
      html.p([attribute.class("text-xs text-base-content/50 mb-2")], [
        html.text(int.to_string(list.length(author.posts)) <> " post(s)"),
      ]),
      case author.posts {
        [] ->
          html.p([attribute.class("text-sm text-base-content/60 italic")], [
            html.text("No posts yet for this author."),
          ])
        posts ->
          html.ul(
            [attribute.class("mt-2 space-y-2 pl-4 list-disc")],
            list.map(posts, post_item),
          )
      },
    ],
  )
}

fn post_item(post: Post) -> Element(Msg) {
  html.li([attribute.id("post-" <> post.id)], [
    html.span([attribute.class("font-medium")], [html.text(post.title)]),
    case post.body {
      "" -> element.none()
      body ->
        html.span([attribute.class("text-base-content/70")], [
          html.text(" — " <> body),
        ])
    },
  ])
}

fn footer_section() -> Element(Msg) {
  html.aside(
    [
      attribute.class(
        "text-sm text-base-content/60 border-t border-base-300 pt-6 space-y-1",
      ),
    ],
    [
      html.p([], [
        html.text("This UI is a Gleam/Lustre "),
        html.strong([], [html.text("server component")]),
        html.text(" at "),
        html.code([attribute.class("px-1")], [html.text("/gleam")]),
        html.text(". Compare with LiveView at "),
        html.a([attribute.href("/blog"), attribute.class("link")], [
          html.text("/blog"),
        ]),
        html.text(" and Hologram at "),
        html.a([attribute.href("/hologram"), attribute.class("link")], [
          html.text("/hologram"),
        ]),
        html.text("."),
      ]),
      html.p([], [
        html.text(
          "State and Ash access live on the BEAM; the browser runs Lustre’s thin client runtime over WebSocket.",
        ),
      ]),
    ],
  )
}
