# Publish to GitHub

Creator: **naph_** · License: **MIT** · Repository slug: **shimeji-nook**

The Shimeji-Nook-Repo folder contains repository source files, without a .git directory or build output. Place its **contents** at the root of your repository, including .github, .gitignore and .gitattributes.

README.md and LICENSE are already provided. Do not generate another license file.

## Using Git

Copy the prepared files into your existing clone, then run:

```bash
git add .
git commit -m "Rename desktop companion to Shimeji Nook"
git push
```

These commands are for the repository owner. This preparation did not push files, create a remote repository or publish a release.

## Repository description

Use [REPOSITORY_DESCRIPTION.md](REPOSITORY_DESCRIPTION.md) for the About / Description field. Preserve the author credit naph_. No GitHub account name or remote URL is assumed.

## Automated builds

.github/workflows/build.yml builds Windows x64 and macOS Universal on pushes to main, pull requests, version tags or manual workflow runs. It uploads verified ZIP files as artifacts; it does not automatically create a GitHub Release.

The workflow has not been executed on GitHub in this preparation. Both applications were rebuilt locally on Mac. The renamed Windows executable still needs a Windows runtime check.

## Release

Use the files in Shimeji-Nook-Releases. Attach both platform ZIPs and SHA256SUMS.txt, and paste RELEASE_NOTES.md into the release description. Do not commit application ZIPs into the source repository.

The macOS application is ad-hoc signed without Developer ID or notarization.
