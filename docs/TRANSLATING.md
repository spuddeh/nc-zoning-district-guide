# Translating NC Zoning District Guide

A translation is **one file**, and it ships as its own mod. Nothing has to change in this mod, and you
do not need to wait for a release. No coding.

## What you are editing

Every language already has a slot in the mod, empty, showing English until someone fills it in:

```text
r6/scripts/NCZoningDistrictGuide/translations/<Language>.reds
```

Open the one for your language. It looks like this, and the three marked lines are the only ones you
touch:

```swift
public class NCZDG_French extends ModLocalizationPackage {     // leave this line alone
  protected func DefineTexts() -> Void {                       // leave this line alone
    // Translations go here. See the instructions at the top of this file.
  }                                                            // leave this line alone
}
```

## Step 1 - copy the text lines out of English.reds, and nothing else

Open `translations/English.reds`. Copy **only** the `this.Text(...)` lines - the ones between the
braces of `DefineTexts`:

```swift
public class NCZDG_English extends ModLocalizationPackage {    <-- do NOT copy this
  protected func DefineTexts() -> Void {                       <-- do NOT copy this
    this.Text("NCZDG.title",      "NC ZONING BOARD");          <-- copy from here
    this.Text("NCZDG.headerLeft", "NIGHT CORP // URBAN PLANNING DIVISION");
    this.Text("NCZDG.close",      "CLOSE");                    <-- down to here
  }                                                            <-- do NOT copy this
}                                                              <-- do NOT copy this
```

> **Do not copy the whole file.** The class is named `NCZDG_English`, and copying it into your file
> leaves two classes with the same name. Redscript compiles every installed mod together, so that
> stops **every** redscript mod on the player's machine from loading - not just this one.

## Step 2 - paste them into your language's file

Replace the `// Translations go here.` line with what you copied. Everything else in the file stays
exactly as it is - the class name in your file is already correct for your language.

## Step 3 - translate the second text on each line

```swift
this.Text("NCZDG.title",  "NC ZONING BOARD");
           ^^^^^^^^^^^^^  the KEY - never change it
                          ^^^^^^^^^^^^^^^^^  translate this
```

The key is how the mod finds the line. Change it and the mod shows the key itself to the player.

## What you do not have to do

- **You do not have to translate everything.** Anything you leave out shows in English. A partial
  translation is normal and will not look broken.
- **You do not have to keep up with updates.** Strings added later show in English until someone
  translates them.
- **You do not have to touch `Provider.reds`.** Your language is already wired up.

## Two things that will bite

**Keep the placeholders in braces.** `{n}`, `{area}`, `{name}` and friends are replaced with a number
or a name when the line is drawn. Keep them spelled exactly as they are - but you may **move** them
anywhere in the sentence. That is why sentences are whole strings rather than pieces glued together:
so you can put the number after the noun, or the area before the count, or drop a word your language
does not need.

**Plurals are separate keys, one per form.** English has two forms, Polish and Russian three, Arabic
six. Fill in the forms your language uses and leave the rest; do not try to make one string cover
them all.

## Packaging it

Zip the file with its folders, starting at `r6`:

```text
MyTranslation.zip
└── r6/
    └── scripts/
        └── NCZoningDistrictGuide/
            └── translations/
                └── French.reds
```

That installs like any other mod. It should load **after** this one, so that its copy of the file is
the one the game uses.

## Credit

Send it over and it can go up as an optional file on the mod page, credited to you - or publish it
yourself as a standalone mod. Either works, and neither needs anything released at this end.
