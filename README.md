# CraftWarn

An addon for patrons looking to create crafting orders. It remembers the last recipe you opened, and warns you when the item you're looking at to craft doesn't match your spec's primary stat.

---

## Features

**Recipe recall** — When you reopen the Customer Orders window, CraftWarn automatically reopens the last recipe you were working on. A small back-arrow button next to the search bar lets you jump back to it manually at any time.

**Stat mismatch warning** — If the item you're crafting has a primary stat (Strength, Agility, Intellect) that doesn't match your current spec, a red warning appears on the order form. Catches the common mistake of crafting a caster weapon for a melee spec.

**Stat match confirmation** — Optionally shows a green confirmation when the item's primary stat *does* match your spec.

**No primary stat info** — Optionally shows a grey note when the item has no primary stat at all (i.e., jewelry).

---

## Settings

Open **Interface → AddOns → CraftWarn** to configure. All options can also be toggled with slash commands (see below).

| Setting | Default | Description |
|---|---|---|
| Restore last recipe and reagents | On | Re-opens your last recipe when the Customer Orders window opens |
| Warn on spec primary-stat mismatch | On | Red warning when the crafted item's stat doesn't match your spec |
| Show confirmation when stat matches spec | Off | Green confirmation when the stat does match |
| Show when crafted item has no primary stat | Off | Grey note for items like rings and necks that lack primary stat |
| Auto-open last recipe when browsing orders | On | Automatically triggers recipe recall on window open |
| Don't auto-open after clicking back | Off | Returns to the last recipe when you click back on the order form |
| Don't auto-open after placing an order | Off | Returns to the last recipe after you place an order |

---

## Commands

`/craftwarn` or `/cw`

| Command | Description |
|---|---|
| `/cw help` | Show all available commands |
| `/cw status` | Print current settings and saved recipe info |
| `/cw reset` | Clear the saved recipe context |
| `/cw restore on\|off` | Toggle recipe restore |
| `/cw autoopen on\|off` | Toggle auto-open on window show |
| `/cw forgetback on\|off` | Toggle forget-on-Back |
| `/cw forgetplace on\|off` | Toggle forget-on-place-order |
| `/cw specwarn on\|off` | Toggle the stat mismatch warning |
| `/cw specmatch on\|off` | Toggle the stat match confirmation |
| `/cw nostatinfo on\|off` | Toggle the no-primary-stat info |

---

## Notes

- CraftWarn goes dormant when not resting (i.e., in a city/neighborhood).
- Warnings only appear for equippable items.
