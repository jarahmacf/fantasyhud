export async function mapWithBoundedConcurrency<Input, Output>(
  values: readonly Input[],
  concurrency: number,
  worker: (value: Input, index: number) => Promise<Output>
): Promise<Output[]> {
  if (!Number.isSafeInteger(concurrency) || concurrency < 1) {
    throw new TypeError("Concurrency must be a positive safe integer.")
  }

  const results = new Array<Output>(values.length)
  let nextIndex = 0
  let failed = false
  let terminalError: unknown

  async function runWorker(): Promise<void> {
    while (!failed) {
      const index = nextIndex
      if (index >= values.length) return
      nextIndex += 1

      try {
        results[index] = await worker(values[index]!, index)
      } catch (error) {
        failed = true
        terminalError = error
        return
      }
    }
  }

  await Promise.all(
    Array.from({ length: Math.min(concurrency, values.length) }, runWorker)
  )

  if (failed) throw terminalError
  return results
}
