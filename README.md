# CraftWarn

An addon for patrons that remembers the last recipe you opened, and warns you when the item you're looking at doesn't match your spec's primary stat or your class armor type.

---

## Features

**Recipe recall** — When you reopen the Customer Orders window, CraftWarn automatically reopens the last recipe you were working on. A small back-arrow button next to the search bar lets you jump back to it manually at any time.

**Stat mismatch warning** — If the item you're crafting has a primary stat (Strength, Agility, Intellect) that doesn't match your current spec, a red warning appears on the order form. Catches the common mistake of crafting a caster weapon for a melee spec.

**Armor-type mismatch warning** — If the item you're crafting is the wrong armor type for your class (e.g., a Warrior crafting Cloth instead of Plate), a red warning appears on the order form.

**Stat match confirmation** — Optionally shows a green confirmation when the item's primary stat *does* match your spec.

**Armor-type match confirmation** — Optionally shows a green confirmation when the item's armor type *does* match your class.

**No primary stat info** — Optionally shows a grey note when the item has no primary stat at all (i.e., jewelry).

---

## Settings

Open **Interface → AddOns → CraftWarn** to configure. All options can also be toggled with slash commands (see below).

| Setting | Default | Description |
|---|---|---|
| Reopen last recipe when browsing orders | On | Automatically triggers recipe recall on window open |
| Warn on spec primary-stat mismatch | On | Red warning when the crafted item's stat doesn't match your spec |
| Warn on class armor-type mismatch | On | Red warning when the crafted armor type doesn't match your class bonus armor |
| Show confirmation when stat matches spec | Off | Green confirmation when the stat does match |
| Show confirmation when armor matches class | Off | Green confirmation when the armor type does match |
| Show when crafted item has no primary stat | Off | Grey note for items like rings and necks that lack a primary stat |
| Don't reopen after clicking back | Off | Suppress auto-open after clicking Back on the order form |
| Don't reopen after placing an order | Off | Suppress auto-open after placing an order |

---

## Commands

`/craftwarn` or `/cwarn`

| Command | Description |
|---|---|
| `/cwarn help` | Show all available commands |
| `/cwarn status` | Print current settings and saved recipe info |
| `/cwarn reset` | Clear the saved recipe context |
| `/cwarn autoopen on\|off` | Toggle auto-open on window show |
| `/cwarn specwarn on\|off` | Toggle the stat mismatch warning |
| `/cwarn armorwarn on\|off` | Toggle the armor-type mismatch warning |
| `/cwarn specmatch on\|off` | Toggle the stat match confirmation |
| `/cwarn armormatch on\|off` | Toggle the armor-type match confirmation |
| `/cwarn nostatinfo on\|off` | Toggle the no-primary-stat info |
| `/cwarn forgetback on\|off` | Toggle forget-on-Back |
| `/cwarn forgetplace on\|off` | Toggle forget-on-place-order |

---

## Notes

- CraftWarn goes dormant when not resting (i.e., in a city/neighborhood).
- Warnings only appear for equippable items.
