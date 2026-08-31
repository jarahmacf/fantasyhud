const controlCharacterPattern = /[\u0000-\u001f\u007f]/u
const internalWhitespacePattern = /\s/u
const pathOrQuerySeparatorPattern = /[\\/?#]/u

export class SleeperUsernameValidationError extends Error {
  constructor() {
    super("Enter a valid Sleeper username.")
    this.name = "SleeperUsernameValidationError"
  }
}

export function normalizeSleeperUsername(value: unknown): string {
  if (typeof value !== "string" || controlCharacterPattern.test(value)) {
    throw new SleeperUsernameValidationError()
  }

  const trimmed = value.trim()
  const username = trimmed.startsWith("@") ? trimmed.slice(1) : trimmed

  if (
    username.length === 0 ||
    username.length > 100 ||
    internalWhitespacePattern.test(username) ||
    pathOrQuerySeparatorPattern.test(username)
  ) {
    throw new SleeperUsernameValidationError()
  }

  return username
}
