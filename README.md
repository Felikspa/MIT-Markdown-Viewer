# MIT Markdown Viewer

MIT Markdown Viewer is a lightweight Flutter Markdown reader for Android. It is built from the open source Flutter Markdown Editor base and refocused as a mobile-first reader for Markdown notes stored in a GitHub repository.

The app is designed for private study repositories: configure a GitHub repo once, browse its Markdown directory tree, read files with LaTeX support, and keep a local cache for offline access.

## Features

- Browse Markdown files from a GitHub repository.
- Supports private repositories with a fine-grained GitHub personal access token.
- Accepts normal GitHub URLs such as `https://github.com/owner/repo.git`.
- Renders Markdown with LaTeX formulas:
  - `$...$`
  - `$$...$$`
  - `\(...\)`
  - `\[...\]`
- One-tap full repository sync for all Markdown files.
- Local Markdown cache for offline reading.
- Cloud version check with GitHub blob `sha`; unchanged files use the local copy.
- Left drawer table of contents generated from Markdown headings.
- Immersive reading mode with auto-hiding top and bottom bars.
- Bottom bar for previous/next Markdown file navigation.
- Theme options: follow system, light, dark.
- Adjustable reading font size.

## GitHub Token

For private repositories, create a GitHub fine-grained personal access token:

1. Open GitHub `Settings`.
2. Go to `Developer settings`.
3. Open `Personal access tokens`.
4. Choose `Fine-grained tokens`.
5. Generate a new token for the target repository.
6. Grant `Contents: Read-only`.
7. Copy the token into the app.

The token is stored with `flutter_secure_storage`.

## Sync and Offline Behavior

The app uses GitHub's repository tree API to list Markdown files and stores each file locally after it is loaded or synced.

When opening a file:

1. The app checks the local cache.
2. If the cached `sha` matches the current GitHub tree entry, it opens the local file immediately.
3. If GitHub has a newer `sha`, the app downloads the new content and updates the cache.
4. If the network request fails but a cached copy exists, the cached copy is opened.

The settings page includes `Sync all Markdown`, which downloads or updates every Markdown file in the configured repository.

## Development

Install dependencies:

```bash
flutter pub get
```

Run checks:

```bash
flutter analyze
flutter test
```

Build Android debug APK:

```bash
flutter build apk --debug
```

The generated APK is written to:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Project Notes

This project currently targets Android first. Desktop, web, editing, PDF export, and local file editing features from the original upstream app are not part of the current reader-focused workflow.

## Attribution

This project is based on [FlutterMarkdownEditor](https://github.com/adeeteya/FlutterMarkdownEditor) by Aditya R, licensed under the MIT License.

## License

MIT License. See [LICENSE](LICENSE).
