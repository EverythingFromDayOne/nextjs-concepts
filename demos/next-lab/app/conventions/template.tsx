export default function ConventionsTemplate({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <div data-marker="template">
      <p>template</p>
      {children}
    </div>
  )
}
