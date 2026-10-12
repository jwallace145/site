import type { ReactNode } from "react";
import BlurFade from "@/components/magicui/blur-fade";
import { DATA } from "@/data/resume";
import Markdown from "react-markdown";

const BLUR_FADE_DELAY = 0.04;

/** Links in an interest's description open in a new tab, like every other outbound link. */
const markdownComponents = {
  a: ({ href, children }: { href?: string; children?: ReactNode }) => (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className="font-medium text-foreground underline decoration-border underline-offset-4 transition-colors hover:decoration-foreground"
    >
      {children}
    </a>
  ),
  p: ({ children }: { children?: ReactNode }) => <>{children}</>,
};

export default function InterestsSection() {
  return (
    <div className="flex flex-col gap-6">
      {DATA.interests.map((interest, index) => (
        <BlurFade key={interest.name} delay={BLUR_FADE_DELAY * 12 + index * 0.05}>
          <div className="flex items-start gap-x-3">
            <div className="flex size-8 flex-none items-center justify-center rounded-full border bg-background shadow ring-2 ring-border md:size-10">
              <interest.icon className="size-4 text-foreground md:size-5" aria-hidden />
            </div>
            <div className="flex min-w-0 flex-1 flex-col gap-1">
              <div className="leading-none font-semibold">{interest.name}</div>
              <p className="font-sans text-sm leading-relaxed text-pretty text-muted-foreground">
                <Markdown components={markdownComponents}>{interest.description}</Markdown>
              </p>
            </div>
          </div>
        </BlurFade>
      ))}
    </div>
  );
}
