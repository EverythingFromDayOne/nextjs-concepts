'use server'

import { updateTag, revalidateTag } from 'next/cache'
import { db } from '@/lib/db'

export async function setPriceWithUpdate(formData: FormData) {
  await db.mutablePlans.setPrice(String(formData.get('id')), Number(formData.get('cents')))
  updateTag('plans')
}

export async function setPriceWithRevalidate(formData: FormData) {
  await db.mutablePlans.setPrice(String(formData.get('id')), Number(formData.get('cents')))
  revalidateTag('plans', 'max')
}
