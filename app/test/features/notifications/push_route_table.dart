/// T092's table: the app's `parsePushRoute` and the web worker's pattern must agree on it.
const List<String> acceptedPushRoutes = [
  '/',
  '/match/5',
  '/match/5?section=channels',
  '/channel/5',
];

const List<String> refusedPushRoutes = [
  '/match/5/x',
  '/match/abc',
  '/match/5?section=x',
  '/match/5?section=channels&x=1',
  '/match/',
  '/match/0',
  '/match/-5',
  '/match/12345678901',
  '/channel/',
  '/channel/5?section=channels',
  '/evil',
  '//host',
  'https://x',
  '/match/5\n',
  '',
];
