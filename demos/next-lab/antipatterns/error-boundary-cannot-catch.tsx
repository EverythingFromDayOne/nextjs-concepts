// antipattern: error.tsx cannot catch errors thrown by the layout in its own
// segment — the boundary sits inside that layout, so a layout throw escapes
// upward. Only a parent segment's error.tsx, or global-error.tsx, catches it.
// fails: at runtime, in the parent boundary — not where you put the file.
export default function BadLayout() {
  throw new Error('layouts throw past their own sibling error.tsx')
}
