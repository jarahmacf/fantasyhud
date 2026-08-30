import type { Metadata } from "next"
import { Geist, Geist_Mono } from "next/font/google"
import type { ReactNode } from "react"

import "./globals.css"

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
})

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
})

export const metadata: Metadata = {
  title: "FANTASY HUD — Repository foundation",
  description:
    "Application, quality gates, and backend status for FANTASY HUD.",
}

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html
      lang="en"
      className={`dark ${geistSans.variable} ${geistMono.variable}`}
    >
      <body className="min-h-svh overflow-x-hidden">{children}</body>
    </html>
  )
}
