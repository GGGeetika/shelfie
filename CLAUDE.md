# Shelfie

## Goal
One place for book recommendations from bookshop photos, screenshots, friends and my own searching, plus help choosing what to read next. A personal TBR manager for one avid reader, installed on my own iPhone from Xcode (no App Store, no TestFlight).

## Stack
- SwiftUI, iOS 17+, SwiftData (local-first)
- PhotoKit + PhotosPicker for photo access
- Apple Vision text recognition, on-device
- Open Library + Google Books for metadata (Open Library first, Google Books fallback)
- Claude API (vision) via a serverless proxy (Vercel), only for photos on-device reading can't identify
- Xcode project is generated from `project.yml` with XcodeGen: `brew install xcodegen && xcodegen generate`. The `.xcodeproj` is not committed.

## Data model
Book, Recommendation, Photo, Club, Shelf, ShelfBook.

## Privacy rules
- No analytics, no third-party SDKs.
- Every upload goes through one `PhotoUploader`.
- Nothing uploads without an explicit tap from me.
- Strip all metadata (EXIF/GPS) before upload.

## Design: "window seat"
Inspired by a Seaport bookshop; no store branding.
- Cream ground `#F3ECDF`, ink `#2A211A`
- Brick `#8E3F2B` for actions and a brick divider
- Walnut shelves `#3B2A1E`
- Brass name-plaques `#B8945A` for lane labels
- Fonts: Libre Caslon Display/Text for titles, Libre Franklin for UI, Kalam for handwritten index cards (bundled in `Shelfie/Resources/Fonts`, OFL)
- Shelf header: an arched, brick-framed window with a red lightship on the water
- Scan results and "why it's here" sit on an oak-table surface with index cards
- Covers are the hero. No emoji in UI.
- Tokens live in `Shelfie/Theme/Theme.swift`.

## Rules
- Small commits.
- Build and run tests before finishing a stage.
- Never commit API keys (the Claude key lives only in Vercel env vars).
- Work in stages; stop after each so I can try it on my phone.
