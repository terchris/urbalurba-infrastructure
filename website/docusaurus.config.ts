import { themes as prismThemes } from 'prism-react-renderer';
import type { Config } from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// GitHub organization and repository from environment or defaults
const GITHUB_ORG = process.env.GITHUB_ORG || 'terchris';
const GITHUB_REPO = process.env.GITHUB_REPO || 'urbalurba-infrastructure';

const config: Config = {
  title: 'Urbalurba Infrastructure Stack',
  tagline: 'Complete datacenter on your laptop',
  favicon: 'img/favicon.ico',

  // Production URL
  url: 'https://uis.sovereignsky.no',
  baseUrl: '/',

  // GitHub Pages deployment config
  organizationName: GITHUB_ORG,
  projectName: GITHUB_REPO,
  trailingSlash: false,

  onBrokenLinks: 'warn',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  markdown: {
    mermaid: true,
    format: 'detect',
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          editUrl: `https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/tree/main/website/`,
        },
        blog: false, // No blog
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themes: ['@docusaurus/theme-mermaid'],

  plugins: [
    'docusaurus-plugin-image-zoom',
    [
      '@easyops-cn/docusaurus-search-local',
      {
        hashed: true,
        language: ['en'],
        highlightSearchTermsOnTargetPage: true,
        explicitSearchResultPath: true,
        docsRouteBasePath: '/docs',
      },
    ],
  ],

  themeConfig: {
    image: 'img/social-card.jpg',
    navbar: {
      title: 'Urbalurba Infrastructure Stack',
      logo: {
        alt: 'Urbalurba Infrastructure Stack Logo',
        src: 'img/brand/uis-logo-green.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'tutorialSidebar',
          position: 'left',
          label: 'Docs',
        },
        {
          href: `https://github.com/${GITHUB_ORG}/${GITHUB_REPO}`,
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Documentation',
          items: [
            {
              label: 'Getting Started',
              to: '/docs/getting-started/overview',
            },
            {
              label: 'Packages',
              to: '/docs/packages/ai',
            },
            {
              label: 'Hosts',
              to: '/docs/hosts',
            },
          ],
        },
        {
          title: 'Resources',
          items: [
            {
              label: 'GitHub',
              href: `https://github.com/${GITHUB_ORG}/${GITHUB_REPO}`,
            },
            {
              label: 'SovereignSky',
              href: 'https://sovereignsky.no',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} SovereignSky. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'yaml', 'json', 'typescript', 'python'],
    },
    zoom: {
      selector: '.markdown img',
      background: {
        light: 'rgb(255, 255, 255)',
        dark: 'rgb(50, 50, 50)',
      },
    },
    colorMode: {
      defaultMode: 'light',
      disableSwitch: false,
      respectPrefersColorScheme: true,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
