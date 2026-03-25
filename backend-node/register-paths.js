/**
 * Runtime path alias registration for compiled TypeScript.
 * Resolves @domain/*, @application/*, etc. to their dist/ equivalents
 * so that `node dist/main.js` works without ts-node.
 */
const { register } = require('tsconfig-paths');
const path = require('path');

register({
  baseUrl: path.resolve(__dirname, '.'),
  paths: {
    '@domain/*': ['dist/domain/*'],
    '@application/*': ['dist/application/*'],
    '@infrastructure/*': ['dist/infrastructure/*'],
    '@interfaces/*': ['dist/interfaces/*'],
    '@config/*': ['dist/config/*'],
  },
});
