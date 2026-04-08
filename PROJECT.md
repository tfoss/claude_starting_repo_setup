# PROJECT.md — Project Brief

## One-liner

A GUI for extracting a logo/icon from an image with various useful image controls and saving as a an .svg file for eventual use in a 3d-printing plate.

## Problem

I want to take logos/icons from some cards and generate an image I can use to emboss onto a 3d printed model. I will use fusion to generate model and eventual .stl, but I need to get the icons into a good print-friendly format and state (e.g. smooth, clear, identifiable). Trying to do this automatically has been challenging, so I want an interface for viewing, and then adjusting parameters to detect, extract, smooth the input image. The UI should also an 'input' and 'output' with extraction parameters also adjustable and results displayed immediately. This can have a feel like common image editors (macos photos 'edit'; pixelmator; photoshop, etc) with a reasonable level of detailed control

## Core Behaviors

### Must-have
- User can load image into application
- User can ask application to extract icon/logo into .svg
- User can view input image with adjustments and output .svg at the same time
- User can click button or other interface item to run extraction
- User can adjust standard parameters for input image manipulation (contrast / brightness /etc) to prepare image for better extraction
- System will analyze image and offer default or suggested parameters for extraction
- User can adjust .svg generation parameters that contribute to the output (smoothness, complexity, etc)

### Nice-to-have
- ability to see histograms of color channels & ability to use them for parameter adjustments
- adjustment of parameters can automatically update the extracted .svg view (or potentially a preview of it)

## Inputs / Outputs

### Inputs
common image file formats

### Outputs
.svg file for use in fusion 360

## Constraints

- **Language**: Python, using **conda** for environment/dependency management.
- **GUI**: performance and good UX behavior are priority

## Non-goals
