import { Badge } from "@/components/ui/badge";
import { DATA } from "@/data/resume";
import { withBase } from "@/lib/utils";
import { Timeline, TimelineItem, TimelineConnectItem } from "@/components/timeline";

export default function HackathonsSection() {
  return (
    <section id="hackathons" className="overflow-hidden">
      <div className="flex min-h-0 w-full flex-col gap-y-8">
        <div className="flex flex-col items-center justify-center gap-y-4">
          <div className="flex w-full items-center">
            <div className="h-px flex-1 bg-linear-to-r from-transparent from-5% via-border via-95% to-transparent" />
            <div className="z-10 rounded-xl border bg-primary px-4 py-1">
              <span className="text-sm font-medium text-background">
                {DATA.sections.hackathons.label}
              </span>
            </div>
            <div className="h-px flex-1 bg-linear-to-l from-transparent from-5% via-border via-95% to-transparent" />
          </div>
          <div className="flex flex-col items-center justify-center gap-y-3">
            <h2 className="text-3xl font-bold tracking-tighter sm:text-4xl">
              {DATA.sections.hackathons.heading}
            </h2>
            <p className="text-center text-balance text-muted-foreground md:text-lg/relaxed lg:text-base/relaxed xl:text-lg/relaxed">
              {DATA.sections.hackathons.text.replace("{count}", String(DATA.hackathons.length))}
            </p>
          </div>
        </div>
        <Timeline>
          {DATA.hackathons.map((hackathon) => (
            <TimelineItem
              key={hackathon.title + hackathon.dates}
              className="flex w-full items-start justify-between gap-10"
            >
              <TimelineConnectItem className="flex items-start justify-center">
                {hackathon.image ? (
                  <img
                    src={withBase(hackathon.image)}
                    alt={hackathon.title}
                    className="z-10 size-10 flex-none shrink-0 overflow-hidden rounded-full border bg-card object-contain p-1 shadow ring-2 ring-border"
                  />
                ) : (
                  <div className="z-10 size-10 flex-none shrink-0 overflow-hidden rounded-full border bg-card p-1 shadow ring-2 ring-border" />
                )}
              </TimelineConnectItem>
              <div className="flex min-w-0 flex-1 flex-col justify-start gap-2">
                {hackathon.dates && (
                  <time className="text-xs text-muted-foreground">{hackathon.dates}</time>
                )}
                {hackathon.title && (
                  <h3 className="leading-none font-semibold">{hackathon.title}</h3>
                )}
                {hackathon.location && (
                  <p className="text-sm text-muted-foreground">{hackathon.location}</p>
                )}
                {hackathon.description && (
                  <p className="text-sm leading-relaxed wrap-break-word text-muted-foreground">
                    {hackathon.description}
                  </p>
                )}
                {hackathon.links && hackathon.links.length > 0 && (
                  <div className="mt-1 flex flex-row flex-wrap items-start gap-2">
                    {hackathon.links.map((link, idx) => (
                      <a href={link.href} key={idx} target="_blank" rel="noopener noreferrer">
                        <Badge className="flex items-center gap-1.5 bg-primary text-xs text-primary-foreground">
                          {link.icon}
                          {link.title}
                        </Badge>
                      </a>
                    ))}
                  </div>
                )}
              </div>
            </TimelineItem>
          ))}
        </Timeline>
      </div>
    </section>
  );
}
