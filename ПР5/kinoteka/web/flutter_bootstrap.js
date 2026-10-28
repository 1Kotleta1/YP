{{flutter_js}}
{{flutter_build_config}}

// CanvasKit загружается с того же сервера, что и приложение, а не с CDN
// www.gstatic.com: без доступа к CDN страница иначе остаётся белой
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
});
