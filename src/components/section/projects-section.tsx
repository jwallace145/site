import BlurFade from "@/components/magicui/blur-fade";
import { ProjectCard } from "@/components/project-card";
import { DATA } from "@/data/resume";
import { cn } from "@/lib/utils";
import { ChevronDown } from "lucide-react";
import { useState } from "react";

const BLUR_FADE_DELAY = 0.04;
const ARCHIVED_PROJECTS_ID = "archived-projects";

type Project = (typeof DATA.projects)[number];

// A project without `active: false` is current. Archived projects stay in the
// portfolio but sit behind a toggle so they don't crowd out current work.
const activeProjects = DATA.projects.filter((p) => p.active !== false);
const archivedProjects = DATA.projects.filter((p) => p.active === false);

function ProjectGrid({ projects, baseDelay }: { projects: readonly Project[]; baseDelay: number }) {
  return (
    <div className="mx-auto grid max-w-[800px] auto-rows-fr grid-cols-1 gap-3 sm:grid-cols-2">
      {projects.map((project, index) => (
        <BlurFade key={project.title} delay={baseDelay + index * 0.05} className="h-full">
          <ProjectCard
            href={project.href}
            title={project.title}
            description={project.description}
            dates={project.dates}
            active={project.active}
            tags={project.technologies}
            image={project.image}
            video={project.video}
            links={project.links}
          />
        </BlurFade>
      ))}
    </div>
  );
}

export default function ProjectsSection() {
  const [showArchived, setShowArchived] = useState(false);

  return (
    <section id="projects">
      <div className="flex min-h-0 flex-col gap-y-8">
        <div className="flex flex-col items-center justify-center gap-y-4">
          <div className="flex w-full items-center">
            <div className="h-px flex-1 bg-linear-to-r from-transparent from-5% via-border via-95% to-transparent" />
            <div className="z-10 rounded-xl border bg-primary px-4 py-1">
              <span className="text-sm font-medium text-background">
                {DATA.sections.projects.label}
              </span>
            </div>
            <div className="h-px flex-1 bg-linear-to-l from-transparent from-5% via-border via-95% to-transparent" />
          </div>
          <div className="flex flex-col items-center justify-center gap-y-3">
            <h2 className="text-3xl font-bold tracking-tighter sm:text-4xl">
              {DATA.sections.projects.heading}
            </h2>
            <p className="text-center text-balance text-muted-foreground md:text-lg/relaxed lg:text-base/relaxed xl:text-lg/relaxed">
              {DATA.sections.projects.text}
            </p>
          </div>
        </div>
        <ProjectGrid projects={activeProjects} baseDelay={BLUR_FADE_DELAY * 12} />
        {archivedProjects.length > 0 && (
          <div className="flex flex-col gap-y-4">
            <button
              type="button"
              onClick={() => setShowArchived((open) => !open)}
              aria-expanded={showArchived}
              aria-controls={ARCHIVED_PROJECTS_ID}
              className="mx-auto flex items-center gap-1.5 rounded-md px-3 py-1.5 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:outline-none"
            >
              {showArchived ? "Hide" : "Show"} archived projects ({archivedProjects.length})
              <ChevronDown
                className={cn("size-4 transition-transform", showArchived && "rotate-180")}
                aria-hidden
              />
            </button>
            <div id={ARCHIVED_PROJECTS_ID} hidden={!showArchived}>
              {showArchived && <ProjectGrid projects={archivedProjects} baseDelay={0} />}
            </div>
          </div>
        )}
      </div>
    </section>
  );
}
