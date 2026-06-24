---
name: Spiritual Minimalism
colors:
  surface: '#f8f9ff'
  surface-dim: '#d0dbed'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e6eeff'
  surface-container-high: '#dee9fc'
  surface-container-highest: '#d9e3f6'
  on-surface: '#121c2a'
  on-surface-variant: '#404944'
  inverse-surface: '#27313f'
  inverse-on-surface: '#eaf1ff'
  outline: '#707974'
  outline-variant: '#bfc9c3'
  surface-tint: '#2b6954'
  primary: '#003527'
  on-primary: '#ffffff'
  primary-container: '#064e3b'
  on-primary-container: '#80bea6'
  inverse-primary: '#95d3ba'
  secondary: '#735c00'
  on-secondary: '#ffffff'
  secondary-container: '#fed65b'
  on-secondary-container: '#745c00'
  tertiary: '#003623'
  on-tertiary: '#ffffff'
  tertiary-container: '#004f35'
  on-tertiary-container: '#23ca90'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#b0f0d6'
  primary-fixed-dim: '#95d3ba'
  on-primary-fixed: '#002117'
  on-primary-fixed-variant: '#0b513d'
  secondary-fixed: '#ffe088'
  secondary-fixed-dim: '#e9c349'
  on-secondary-fixed: '#241a00'
  on-secondary-fixed-variant: '#574500'
  tertiary-fixed: '#68fcbf'
  tertiary-fixed-dim: '#45dfa4'
  on-tertiary-fixed: '#002114'
  on-tertiary-fixed-variant: '#005137'
  background: '#f8f9ff'
  on-background: '#121c2a'
  surface-variant: '#d9e3f6'
typography:
  display-lg:
    fontFamily: ebGaramond
    fontSize: 48px
    fontWeight: '600'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: ebGaramond
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: ebGaramond
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
  headline-md:
    fontFamily: ebGaramond
    fontSize: 24px
    fontWeight: '500'
    lineHeight: 32px
  body-lg:
    fontFamily: plusJakartaSans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: plusJakartaSans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: plusJakartaSans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.05em
  caption:
    fontFamily: plusJakartaSans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  2xl: 48px
  margin-mobile: 20px
  gutter-mobile: 12px
---

## Brand & Style
The design system centers on a "Spiritual Minimalist" aesthetic, blending the profound heritage of Islamic art with contemporary digital clarity. The goal is to create a sanctuary-like digital environment that feels calm, premium, and intentional. 

The visual language avoids clutter, using generous whitespace to allow content—such as Quranic verses or prayer times—to breathe. It draws inspiration from modern architectural minimalism and classical calligraphy, prioritizing legibility and a sense of "quiet luxury." The emotional response should be one of peace, reverence, and focused devotion.

## Colors
The palette is rooted in traditional Islamic symbolism but executed with modern saturation levels. 

- **Primary (Deep Emerald):** Used for key branding, header backgrounds, and primary navigation states. It represents growth and life.
- **Secondary (Gold):** Reserved for accents, highlights, and moments of celebration (e.g., completed goals, premium features). Use sparingly to maintain its "precious" quality.
- **Neutral/Background:** In light mode, the soft cream (#FDFBF7) provides a warmer, more organic feel than pure white, reducing eye strain during long reading sessions. In dark mode, the midnight green (#022C22) maintains the brand identity while providing a high-contrast environment for nighttime use.

## Typography
This design system employs a sophisticated typographic pairing to bridge the gap between tradition and technology.

- **Headlines (ebGaramond):** A classical serif that echoes the elegance of printed scriptures. It is used for titles and significant statements to convey authority and timelessness.
- **Body & UI (plusJakartaSans):** A modern, soft sans-serif that ensures high legibility on mobile screens. Its slightly rounded terminals complement the organic feel of the brand.

For Arabic text, ensure the line-height is increased by at least 20% compared to Latin text to accommodate diacritics (tashkeel) without clipping.

## Layout & Spacing
The layout follows a 4-column fluid grid for mobile, with a strong emphasis on vertical rhythm. 

- **Generous Margins:** A minimum of 20px side margins is required to prevent the UI from feeling cramped.
- **Section Breathing Room:** Use `2xl` (48px) spacing between major content blocks to create a sense of transition and mental pause.
- **Arabesque Dividers:** Instead of simple hair-lines, use subtle, low-opacity geometric patterns or custom-drawn Islamic motifs as dividers to reinforce the spiritual theme. These should be set at 10-15% opacity.

## Elevation & Depth
Depth is created through **Tonal Layering** rather than heavy shadows.

- **Surface Levels:** The base background is the lowest level. Cards and containers use a slightly lighter (in dark mode) or more saturated (in light mode) tint to appear "raised."
- **Soft Glows:** For the primary action buttons, use a very soft, diffused shadow tinted with the primary Emerald color (e.g., `rgba(6, 78, 59, 0.15)`).
- **Glassmorphism:** Use for bottom navigation bars and top app bars with a high background blur (20px+) to maintain a sense of space and continuity as the user scrolls.

## Shapes
The shape language is "Rounded," reflecting the organic and infinite nature often found in Islamic geometry. 

Standard components (buttons, inputs) use a **0.5rem (8px)** radius. Larger cards or "feature" containers should use **1rem (16px)** to feel softer and more inviting. Fully circular shapes are reserved exclusively for avatars and icon containers to provide a distinct visual anchor.

## Components
- **Buttons:** Primary buttons use a solid Deep Emerald fill with white or gold text. Secondary buttons should be outlined with a 1.5px border. Use "Gold" sparingly for high-value actions like "Donate" or "Complete."
- **Cards:** Use a very subtle 1px border (#E5E7EB in light mode) combined with a slight tonal shift for the background. Cards should never feel "heavy."
- **Input Fields:** Use a "floating label" style with a focus state that changes the border color to Deep Emerald.
- **Progress Bars:** For prayer times or Quran reading progress, use a thin, elegant line with a Gold indicator.
- **Chips/Tags:** Small, rounded-pill shapes used for categories (e.g., "Makkah," "Medina," "Sunnah"). Use light tints of the primary color for the background.
- **Prayer Time Cards:** A specific component featuring a subtle arabesque pattern background, with the current prayer time highlighted using the Gold accent.