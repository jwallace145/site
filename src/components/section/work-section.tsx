import { useState } from "react";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { DATA } from "@/data/resume";
import { ChevronDown, ChevronRight } from "lucide-react";
import { cn, withBase } from "@/lib/utils";

function LogoImage({ src, alt }: { src: string; alt: string }) {
  const [imageError, setImageError] = useState(false);

  if (!src || imageError) {
    return (
      <div className="size-8 flex-none rounded-full border bg-muted p-1 shadow ring-2 ring-border md:size-10" />
    );
  }

  return (
    <img
      src={src}
      alt={alt}
      className="size-8 flex-none overflow-hidden rounded-full border bg-white object-contain p-1 shadow ring-2 ring-border md:size-10"
      onError={() => setImageError(true)}
    />
  );
}

function DateRange({ start, end }: { start: string; end: string | undefined }) {
  return (
    <span className="text-xs text-muted-foreground tabular-nums">
      {start} - {end ?? DATA.sections.work.presentLabel}
    </span>
  );
}

export default function WorkSection() {
  return (
    <Accordion type="single" collapsible className="grid w-full gap-6">
      {DATA.work.map((work) => {
        // Roles are most recent first: the company's tenure spans the last
        // role's start to the first role's end.
        const newest = work.roles[0];
        const oldest = work.roles[work.roles.length - 1];
        const multiRole = work.roles.length > 1;

        return (
          <AccordionItem
            key={work.company}
            value={work.company}
            className="grid w-full gap-2 border-b-0"
          >
            <AccordionTrigger className="group cursor-pointer rounded-none p-0 transition-colors hover:no-underline [&>svg]:hidden">
              <div className="flex w-full items-start gap-x-3 text-left">
                <LogoImage src={withBase(work.logoUrl)} alt={work.company} />
                <div className="flex min-w-0 flex-1 flex-col gap-1">
                  {/* Company row: name plus overall tenure. */}
                  <div className="flex flex-col gap-0.5 sm:flex-row sm:items-center sm:justify-between sm:gap-x-3">
                    <div className="flex items-center gap-2 leading-none font-semibold">
                      {work.company}
                      <span className="relative inline-flex h-3.5 w-3.5 items-center">
                        <ChevronRight
                          className={cn(
                            "absolute h-3.5 w-3.5 shrink-0 stroke-2 text-muted-foreground transition-all duration-300 ease-out",
                            "translate-x-0 opacity-0",
                            "group-hover:translate-x-1 group-hover:opacity-100",
                            "group-data-[state=open]:translate-x-0 group-data-[state=open]:opacity-0",
                          )}
                        />
                        <ChevronDown
                          className={cn(
                            "absolute h-3.5 w-3.5 shrink-0 stroke-2 text-muted-foreground transition-all duration-200",
                            "rotate-0 opacity-0",
                            "group-data-[state=open]:rotate-180 group-data-[state=open]:opacity-100",
                          )}
                        />
                      </span>
                    </div>
                    <div className="flex flex-none sm:text-right">
                      <DateRange start={oldest.start} end={newest.end} />
                    </div>
                  </div>
                  {/* One block per role. Several roles under one company read
                      as a promotion, each with its own dates. */}
                  <div className={cn("flex flex-col", multiRole ? "gap-2.5" : "gap-0.5")}>
                    {work.roles.map((role) => (
                      <div key={role.title} className="flex flex-col gap-0.5">
                        <div className="flex flex-col sm:flex-row sm:items-baseline sm:justify-between sm:gap-x-3">
                          <div className="font-sans text-sm text-foreground/90">{role.title}</div>
                          {multiRole && (
                            <div className="flex flex-none sm:text-right">
                              <DateRange start={role.start} end={role.end} />
                            </div>
                          )}
                        </div>
                        <div className="font-sans text-xs text-muted-foreground">{role.team}</div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </AccordionTrigger>
            <AccordionContent className="ml-13 flex flex-col gap-4 p-0 text-xs text-muted-foreground sm:text-sm">
              {work.roles.map((role) => (
                <div key={role.title} className="flex flex-col gap-2">
                  {multiRole && (
                    <div className="font-medium text-foreground">
                      {role.title}{" "}
                      <span className="font-normal text-muted-foreground">
                        · {role.start} - {role.end ?? DATA.sections.work.presentLabel}
                      </span>
                    </div>
                  )}
                  <ul className="list-disc space-y-2 pl-4">
                    {role.bullets.map((item) => (
                      <li key={item}>{item}</li>
                    ))}
                  </ul>
                </div>
              ))}
            </AccordionContent>
          </AccordionItem>
        );
      })}
    </Accordion>
  );
}
