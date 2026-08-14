import { connection } from 'next/server'

export default async function ConventionsPage() {
  // Forces a request-time render so the loading boundary is exercised.
  await connection()
  return <p data-marker="page">page</p>
}
