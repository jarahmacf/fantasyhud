type StatusCardProps = {
  label: string
  value: string
  detail: string
}

export function StatusCard({ label, value, detail }: StatusCardProps) {
  return (
    <article
      data-testid="status-card"
      className="flex min-h-32 flex-col rounded-md border bg-card p-4"
    >
      <p className="text-xs font-medium text-muted-foreground">{label}</p>
      <p className="mt-2 font-mono text-2xl font-semibold tracking-tight text-white tabular-nums">
        {value}
      </p>
      <p className="mt-auto pt-4 text-xs leading-5 text-muted-foreground">
        {detail}
      </p>
    </article>
  )
}
