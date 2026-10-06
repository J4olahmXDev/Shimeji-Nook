# Development instructions

Shimeji Nook is an open-source desktop companion created by naph_, licensed under MIT. Read README.md before changing the existing implementation.

Keep Windows-source and macOS-source side by side: both platforms share macOS-source/ShimejiNook/Assets. The repository slug is shimeji-nook. Display the application name as Shimeji Nook; code identifiers use ShimejiNook.

Preserve the separate ThungNgern and Artist models and their dialogue. Artist is a male character with a temporary name; do not infer any real artist's identity from the artwork. The original model ID remains thungngern.

Keep the menu compact with full readable labels. Put Emotes, Change Model and Say near the top and red Quit at the bottom. Opening menus must not resize the character. Climbing means the side of application windows, not screen edges.

Close old instances before testing new builds. Verify the actual UI, not only compilation, and report platform-specific checks that were not performed. Version 0.6.0 was rebuilt on Mac for both platforms; the renamed Windows executable still requires a Windows runtime check.

Do not change artwork or dialogue unless the requested work requires it. Retain the MIT license and author credits. Publishing or pushing changes requires explicit user authorization.

Use English for all Markdown documentation. README.md may include Thai alongside English. Keep Thai character dialogue in the application.
