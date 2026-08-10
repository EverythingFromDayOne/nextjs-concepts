'use client'

// client: owns the filter text state
import { createContext, useContext, useState } from 'react'

const FilterContext = createContext('')
export const useFilter = () => useContext(FilterContext)

export function FilterShell({ children }: { children: React.ReactNode }) {
  const [filter, setFilter] = useState('')

  return (
    <FilterContext.Provider value={filter}>
      <input
        value={filter}
        placeholder="Filter…"
        onChange={(e) => setFilter(e.target.value)}
      />
      {children}
    </FilterContext.Provider>
  )
}
