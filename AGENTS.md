# Repository Guidelines

## Branch Safety Rules (CRITICAL)

**NEVER make code changes directly on `main` branch.**

Before making ANY code changes:
1. Check current branch: `git branch --show-current`
2. If on `main`, create a new branch IMMEDIATELY: `git checkout -b tm/jeffrey.schmitz2/jdi/{descriptive-name}`
3. Only then proceed with edits

This rule has NO exceptions. Even small fixes require a branch.

## Project Structure & Module Organization
- `ios/` contains the native iOS app (SwiftUI + TCA). Open `ios/DemocracyDJ.xcodeproj` in Xcode.
- `web/` is the React + TypeScript prototype (Vite + Tailwind). Source lives in `web/src/`, assets in `web/src/assets/`, and static files in `web/public/`.
- `shared/` is a Swift Package for shared models and logic, with tests in `shared/Tests/`.
- `docs/` contains design exports and architecture diagrams.

## Build, Test, and Development Commands
- `cd web && npm install` installs web dependencies.
- `cd web && npm run dev` starts the Vite dev server.
- `cd web && npm run build` type-checks and builds the web app.
- `cd web && npm run lint` runs ESLint on the web code.
- `cd web && npm run preview` serves the production build locally.
- `swift test --package-path shared` runs Swift Package tests (if you have Swift toolchain installed).

## Coding Style & Naming Conventions
- Web code uses TypeScript + React with ESLint (`web/eslint.config.js`).
- Follow the existing TS/TSX patterns: 2-space indentation, semicolons, and single quotes.
- React components are PascalCase; hooks start with `use` (see `web/src/App.tsx`).
- Swift code follows standard Swift conventions; keep shared model names aligned with the web prototypes where possible.

## Testing Guidelines
- Swift package tests live in `shared/Tests/SharedTests/` and use XCTest conventions.
- The web prototype has no test runner configured yet; add tests only if you also add tooling.
- Prefer small, focused tests that mirror voting logic and shared model behavior.

## Commit & Pull Request Guidelines
- Git history uses Conventional Commits (example: `chore: monorepo scaffold (ios, web, shared)`); follow that format.
- Branch names should follow the pattern `tm/jeffrey.schmitz2/jdi/<short-description>`.
- PRs should include a brief summary, the area touched (`ios`, `web`, `shared`), and screenshots for UI changes.
- Link relevant issues or design docs from `docs/` when applicable.

## Configuration & Tips
- The web prototype is meant for fast iteration; avoid deep iOS dependencies in `web/`.
- For mesh testing, iOS work typically requires two physical devices.
