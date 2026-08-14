// antipattern: 'use client' at the page root for content that never changes
// and has no interaction. The whole subtree joins the client bundle, the
// prose leaves the prerendered HTML, and nothing is gained.
// fails: silently — it works, which is the problem.
'use client'

export default function AboutPage() {
  return (
    <main>
      <h1>About us</h1>
      <p>Founded in 2019. We make things.</p>
    </main>
  )
}
