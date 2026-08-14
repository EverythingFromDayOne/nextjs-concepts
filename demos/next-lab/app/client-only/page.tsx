import { HeavyWidgetClientOnly } from './loader'

export default function ClientOnlyPage() {
  return (
    <main>
      <h1>Client-only rendering</h1>
      <p>This paragraph is prerendered and will appear in the HTML.</p>
      <HeavyWidgetClientOnly />
    </main>
  )
}
