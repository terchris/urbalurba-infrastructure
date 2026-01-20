# Brand Assets

This folder contains the source branding assets and scripts for generating website images.

## Quick Start

Run these scripts inside the devcontainer where ImageMagick is available:

```bash
# Generate and publish all assets
./create-social-card.sh $'Urbalurba\nInfrastructure\nStack' $'Complete datacenter\non your laptop.'
./publish-social-card.sh
./publish-logo.sh
./publish-favicon.sh
```

## Files Overview

### Source Logos
| File | Purpose |
|------|---------|
| `uis-logo-green.svg` | Main logo (light mode) |
| `uis-logo-teal.svg` | Logo variant (dark mode) |
| `uis-text-green.svg` | Logo with "UIS" text (used in social card) |

### Social Card Assets
| File | Purpose |
|------|---------|
| `social-card-background-gemini.png` | Original background from Gemini (has watermark) |
| `social-card-background.png` | Cleaned background (watermark removed) |
| `social-card-generated.png` | Final social card with text and logo |

### Scripts
| Script | Purpose |
|--------|---------|
| `remove-gemini-stars.sh` | Remove Gemini watermark stars from images |
| `create-social-card.sh` | Generate social card with title, tagline, and logo |
| `publish-social-card.sh` | Publish social card to `../social-card.jpg` |
| `publish-logo.sh` | Publish logo to `../logo.svg` |
| `publish-favicon.sh` | Generate and publish favicon to `../favicon.ico` |

## Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. PREPARE BACKGROUND                                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   social-card-background-gemini.png                             │
│              │                                                  │
│              ▼                                                  │
│   ./remove-gemini-stars.sh -left input.png output.png           │
│              │                                                  │
│              ▼                                                  │
│   social-card-background.png (cleaned)                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ 2. GENERATE SOCIAL CARD                                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   social-card-background.png + uis-text-green.svg               │
│              │                                                  │
│              ▼                                                  │
│   ./create-social-card.sh "Title" "Tagline"                     │
│              │                                                  │
│              ▼                                                  │
│   social-card-generated.png                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ 3. PUBLISH TO WEBSITE                                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ./publish-social-card.sh  →  ../social-card.jpg               │
│   ./publish-logo.sh         →  ../logo.svg                      │
│   ./publish-favicon.sh      →  ../favicon.ico                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Output Files

The publish scripts create these files in the parent folder (`static/img/`):

| File | Used By |
|------|---------|
| `social-card.jpg` | Open Graph / Twitter cards |
| `logo.svg` | Navbar logo |
| `favicon.ico` | Browser tab icon |

## tmp/

Contains unused concept and draft files that are kept for reference.
