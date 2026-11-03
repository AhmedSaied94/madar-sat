import path from 'node:path';

import js from '@eslint/js';
import jsxA11y from 'eslint-plugin-jsx-a11y';
import reactHooks from 'eslint-plugin-react-hooks';
import tailwind from 'eslint-plugin-tailwindcss';
import globals from 'globals';
import tseslint from 'typescript-eslint';

// The text-style classes defined by the generated tokens.css (not Tailwind utilities).
const tokenTextStyles = [
  'score',
  'kickoff',
  'heading-1',
  'heading-2',
  'row-time',
  'row-score',
  'text-body',
  'text-strong',
  'text-label',
  'text-caption',
  'text-micro',
  'readout',
  'readout-lg',
  'readout-xl',
  'mono-code',
];

export default tseslint.config(
  {
    ignores: ['dist/', 'coverage/', 'src/api/generated/','src/styles/tokens.ts'],
  },
  js.configs.recommended,
  tseslint.configs.strict,
  jsxA11y.flatConfigs.recommended,
  tailwind.configs['flat/recommended'],
  {
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      globals: globals.browser,
    },
    plugins: {
      'react-hooks': reactHooks,
    },
    settings: {
      tailwindcss: {
        // Absolute: the plugin resolves tailwindcss from the config's folder.
        config: path.join(import.meta.dirname, 'tailwind.config.ts'),
        callees: ['clsx', 'cva', 'cx'],
        whitelist: [...tokenTextStyles, 'login-orbits'],
      },
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-non-null-assertion': 'error',
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
      // Components such as <RoleChip role="admin"> take a `role` prop that is not an ARIA role.
      'jsx-a11y/aria-role': ['error', { ignoreNonDOM: true }],
      'tailwindcss/no-arbitrary-value': 'error',
      'tailwindcss/no-custom-classname': 'error',
      // Ordering is a formatting concern, not a review finding.
      'tailwindcss/classnames-order': 'off',
    },
  },
  {
    files: ['*.config.{js,ts}', 'scripts/**/*.{js,mjs}'],
    languageOptions: {
      globals: globals.node,
    },
  },
  {
    files: ['e2e/**/*.ts'],
    languageOptions: {
      globals: globals.node,
    },
  },
);
