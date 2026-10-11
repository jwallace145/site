# site

Personal website of Jimmy Wallace. A static [Astro](https://astro.build) site
deployed to AWS S3 + CloudFront.

**Live:** <!-- TODO: live URL -->

## Stack

- Astro, TypeScript, React islands, Tailwind CSS v4, MDX
- pnpm (pinned in `package.json`), Node LTS (pinned in `.nvmrc`)

## Local development

```bash
nvm use
corepack enable   # or: npm i -g pnpm
pnpm install
pnpm dev          # http://localhost:4321
pnpm build        # static output in dist/
pnpm check        # astro check (types + templates)
```

Content lives in three places:

| File                     | Controls                                                   |
| ------------------------ | ---------------------------------------------------------- |
| `src/data/resume.tsx`    | Name, bio, work, education, projects, skills, social links |
| `src/data/config.ts`     | Site URL, SEO, theme colors, font size                     |
| `src/content/blog/*.mdx` | Blog posts                                                 |

Search for `TODO:` to find every placeholder.

## Credits

Built from the [Starfolio](https://github.com/webrating/starfolio) Astro
template, itself a port of
[dillionverma/portfolio](https://github.com/dillionverma/portfolio). Both are
MIT licensed; their notices are retained in [NOTICE](NOTICE).

## License

[MIT](LICENSE)
