export class NotAuthorized extends Error {}

/**
 * Deliberately NOT cached. An authorization decision that lives inside a
 * cached scope is an authorization decision that can be replayed for
 * someone who was never authorized.
 */
export async function assertCanViewUsage(viewerUid: string, targetUid: string) {
  if (viewerUid !== targetUid) throw new NotAuthorized('not your usage')
  return true
}
