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

type Role = (typeof DATA.work)[number]["roles"][number];

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

/** Hover/open indicator used by every accordion trigger in this section. */
function Chevrons() {
  return (
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
  );
}

function Bullets({ items }: { items: Role["bullets"] }) {
  return (
    <ul className="list-disc space-y-2 pl-4">
      {items.map((item) => (
        <li key={item}>{item}</li>
      ))}
    </ul>
  );
}

const triggerClass =
  "group cursor-pointer rounded-none p-0 transition-colors hover:no-underline [&>svg]:hidden";
const contentClass = "p-0 text-xs text-muted-foreground sm:text-sm";

/**
 * A company with one role: the whole row toggles the bullets, as in the
 * original template.
 */
function SingleRole({ work, role }: { work: (typeof DATA.work)[number]; role: Role }) {
  return (
    <AccordionItem value={work.company} className="grid w-full gap-2 border-b-0">
      <AccordionTrigger className={triggerClass}>
        <div className="flex w-full items-start gap-x-3 text-left">
          <LogoImage src={withBase(work.logoUrl)} alt={work.company} />
          <div className="flex min-w-0 flex-1 flex-col gap-0.5">
            <div className="flex flex-col gap-0.5 sm:flex-row sm:items-center sm:justify-between sm:gap-x-3">
              <div className="flex items-center gap-2 leading-none font-semibold">
                {work.company}
                <Chevrons />
              </div>
              <DateRange start={role.start} end={role.end} />
            </div>
            <div className="font-sans text-sm text-foreground/90">{role.title}</div>
            <div className="font-sans text-xs text-muted-foreground">{role.team}</div>
          </div>
        </div>
      </AccordionTrigger>
      <AccordionContent className={cn(contentClass, "ml-13")}>
        <Bullets items={role.bullets} />
      </AccordionContent>
    </AccordionItem>
  );
}

/**
 * A company with several roles (a promotion): the company row is static and
 * shows the overall tenure; each role hangs off a segmented timeline and
 * toggles its own bullets independently.
 */
function MultiRole({ work }: { work: (typeof DATA.work)[number] }) {
  const newest = work.roles[0];
  const oldest = work.roles[work.roles.length - 1];

  return (
    <div className="flex w-full items-start gap-x-3">
      <LogoImage src={withBase(work.logoUrl)} alt={work.company} />
      <div className="flex min-w-0 flex-1 flex-col">
        <div className="flex flex-col gap-0.5 sm:flex-row sm:items-center sm:justify-between sm:gap-x-3">
          <div className="leading-none font-semibold">{work.company}</div>
          <DateRange start={oldest.start} end={newest.end} />
        </div>
        <Accordion type="multiple" className="mt-3 flex flex-col gap-5">
          {work.roles.map((role) => (
            <AccordionItem
              key={role.title}
              value={role.title}
              className={cn(
                // Timeline: a dot centred on a 1px rail. The rail runs from
                // just below the dot to just above the next role's dot, and
                // stops after the last role.
                "relative border-b-0 pl-6",
                "before:absolute before:top-[21px] before:-bottom-4 before:left-1 before:w-px before:bg-border",
                "last:before:hidden",
              )}
            >
              <span
                aria-hidden
                className="absolute top-1.5 left-0 size-[9px] rounded-full bg-muted-foreground"
              />
              <AccordionTrigger className={triggerClass}>
                <div className="flex w-full flex-col gap-0.5 text-left">
                  <div className="flex flex-col gap-0.5 sm:flex-row sm:items-baseline sm:justify-between sm:gap-x-3">
                    <div className="flex items-center gap-2 font-sans text-sm leading-5 font-medium text-foreground/90">
                      {role.title}
                      <Chevrons />
                    </div>
                    <div className="flex flex-none sm:text-right">
                      <DateRange start={role.start} end={role.end} />
                    </div>
                  </div>
                  <div className="font-sans text-xs text-muted-foreground">{role.team}</div>
                </div>
              </AccordionTrigger>
              <AccordionContent className={cn(contentClass, "pt-3")}>
                <Bullets items={role.bullets} />
              </AccordionContent>
            </AccordionItem>
          ))}
        </Accordion>
      </div>
    </div>
  );
}

export default function WorkSection() {
  return (
    <Accordion type="single" collapsible className="grid w-full gap-6">
      {DATA.work.map((work) =>
        work.roles.length > 1 ? (
          <MultiRole key={work.company} work={work} />
        ) : (
          <SingleRole key={work.company} work={work} role={work.roles[0]} />
        ),
      )}
    </Accordion>
  );
}
