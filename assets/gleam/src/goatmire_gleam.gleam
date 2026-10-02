import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import rsvp

// ---------------------------------------------------------------------------
// Domain types (mirror Ash Author / Post JSON from /api)
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
  /// Prefer FormData from the submit event so automation / paste still works
  /// even if `on_input` did not update the model.
  SubmitAuthor(List(#(String, String)))
  SubmitPost(List(#(String, String)))
  AuthorCreateFinished(Result(Author, String))
  PostCreateFinished(Result(Post, String))
  BlogChanged
}

// ---------------------------------------------------------------------------
// Entry
// ---------------------------------------------------------------------------

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

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

  #(model, effect.batch([load_authors(), subscribe_sse()]))
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
          create_author(name),
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
          create_post(author_id, title, body),
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
      // List refresh also arrives via SSE; reload immediately for this tab.
      load_authors(),
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
      load_authors(),
    )

    PostCreateFinished(Error(message)) -> #(
      Model(..model, error: Some(message), flash: None),
      effect.none(),
    )

    BlogChanged -> #(model, load_authors())
  }
}

// ---------------------------------------------------------------------------
// HTTP + SSE effects
// ---------------------------------------------------------------------------

fn load_authors() -> Effect(Msg) {
  let decoder = {
    use data <- decode.field("data", decode.list(author_decoder()))
    decode.success(data)
  }

  rsvp.get("/api/authors", rsvp.expect_json(decoder, map_authors_result))
}

fn map_authors_result(result: Result(List(Author), rsvp.Error(String))) -> Msg {
  AuthorsLoaded(result_to_string_error(result))
}

fn create_author(name: String) -> Effect(Msg) {
  let body = json.object([#("name", json.string(name))])
  let decoder = {
    use data <- decode.field("data", author_decoder())
    decode.success(data)
  }

  rsvp.post(
    "/api/authors",
    body,
    rsvp.expect_json(decoder, map_author_create_result),
  )
}

fn map_author_create_result(result: Result(Author, rsvp.Error(String))) -> Msg {
  AuthorCreateFinished(result_to_string_error(result))
}

fn create_post(author_id: String, title: String, body: String) -> Effect(Msg) {
  let payload =
    json.object([
      #("author_id", json.string(author_id)),
      #("title", json.string(title)),
      #("body", json.string(body)),
    ])

  let decoder = {
    use data <- decode.field("data", post_decoder())
    decode.success(data)
  }

  rsvp.post(
    "/api/posts",
    payload,
    rsvp.expect_json(decoder, map_post_create_result),
  )
}

fn map_post_create_result(result: Result(Post, rsvp.Error(String))) -> Msg {
  PostCreateFinished(result_to_string_error(result))
}

fn result_to_string_error(
  result: Result(a, rsvp.Error(String)),
) -> Result(a, String) {
  case result {
    Ok(value) -> Ok(value)
    Error(error) -> Error(rsvp_error_to_string(error))
  }
}

fn rsvp_error_to_string(error: rsvp.Error(String)) -> String {
  case error {
    rsvp.BadBody -> "Invalid response body from API"
    rsvp.BadUrl(url) -> "Bad API URL: " <> url
    rsvp.HttpError(response) ->
      "HTTP " <> int.to_string(response.status) <> " from API"
    rsvp.JsonError(_) -> "Could not decode API JSON"
    rsvp.NetworkError -> "Network error talking to API"
    rsvp.UnhandledResponse(response) ->
      "Unexpected HTTP " <> int.to_string(response.status)
  }
}

@external(javascript, "./sse_ffi.mjs", "subscribe")
fn do_subscribe_sse(url: String, on_event: fn() -> Nil) -> Nil

fn subscribe_sse() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    do_subscribe_sse("/api/blog/events", fn() { dispatch(BlogChanged) })
  })
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
      [html.text("Ash + Gleam/Lustre demo")],
    ),
    html.h1([attribute.class("text-3xl font-bold")], [
      html.text("Goatmire Blog"),
    ]),
    html.p([attribute.class("text-base-content/80")], [
      html.text(
        "Same domain as LiveView and Hologram: create an Author, then add Posts. Open this page in two browser tabs — changes sync via Server-Sent Events bridged from Ash PubSub.",
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
        html.text("This UI is Gleam/Lustre at "),
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
          "State lives in the browser; Ash is reached over JSON HTTP. Multi-tab sync uses SSE from Ash PubSub.",
        ),
      ]),
    ],
  )
}
