export default function ConventionsLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <div data-marker="layout">
      <p>layout</p>
      {children}
    </div>
  )
}
