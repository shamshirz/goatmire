export function subscribe(url, onEvent) {
  const source = new EventSource(url);

  const notify = () => {
    try {
      onEvent();
    } catch (error) {
      console.error("Gleam SSE handler error", error);
    }
  };

  source.addEventListener("blog_changed", notify);
  source.onmessage = notify;
  // EventSource reconnects automatically; keep the connection open for the tab lifetime.
  source.onerror = () => {
    // Browser will retry; no-op here.
  };

  return source;
}
