import 'dart:html' as html;

void registerBeforeUnload(void Function() callback) {
  html.window.onBeforeUnload.listen((_) => callback());
}

String? readLocalStorage(String key) {
  return html.window.localStorage[key];
}

void writeLocalStorage(String key, String value) {
  html.window.localStorage[key] = value;
}

void removeLocalStorage(String key) {
  html.window.localStorage.remove(key);
}

String currentPageUrl() => html.window.location.href;

void navigateToUrl(String url) {
  html.window.location.assign(url);
}
