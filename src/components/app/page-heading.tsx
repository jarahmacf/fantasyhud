type PageHeadingProps = {
  title: string
  description: string
}

export function PageHeading({ title, description }: PageHeadingProps) {
  return (
    <div className="flex flex-col gap-1">
      <p className="font-mono text-[10px] uppercase tracking-[0.16em] text-blue-400">
        System status
      </p>
      <h1 className="text-2xl font-semibold tracking-tight text-white sm:text-[1.75rem]">
        {title}
      </h1>
      <p className="text-sm text-muted-foreground">{description}</p>
    </div>
  )
}
