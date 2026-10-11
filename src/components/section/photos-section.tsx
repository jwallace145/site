import BlurFade from "@/components/magicui/blur-fade";
import { DATA } from "@/data/resume";
import { withBase } from "@/lib/utils";

const BLUR_FADE_DELAY = 0.04;

// Aspect ratios per column: outer cols are square, middle col is portrait
const colAspects = [
  ["aspect-square", "aspect-square", "aspect-square"],
  ["aspect-[3/4]", "aspect-[4/3]", "aspect-[3/4]"],
  ["aspect-square", "aspect-square", "aspect-square"],
];

export default function PhotosSection() {
  const photos = DATA.photos;
  const col1 = photos.filter((_, i) => i % 3 === 0);
  const col2 = photos.filter((_, i) => i % 3 === 1);
  const col3 = photos.filter((_, i) => i % 3 === 2);

  return (
    <section id="photos">
      <div className="flex min-h-0 flex-col gap-y-4">
        <div className="flex w-full items-center">
          <div className="h-px flex-1 bg-linear-to-r from-transparent from-5% via-border via-95% to-transparent" />
          <div className="z-10 rounded-xl border bg-primary px-4 py-1">
            <span className="text-sm font-medium text-background">Photos</span>
          </div>
          <div className="h-px flex-1 bg-linear-to-l from-transparent from-5% via-border via-95% to-transparent" />
        </div>
        <div className="flex flex-col items-center justify-center gap-y-3">
          <h2 className="text-3xl font-bold tracking-tighter sm:text-4xl">
            {DATA.sections.photos.heading}
          </h2>
        </div>
        <div className="grid grid-cols-2 items-start gap-2 sm:grid-cols-3">
          {[col1, col2, col3].map((col, colIdx) => (
            <div key={colIdx} className="flex flex-col gap-2">
              {col.map((photo, idx) => (
                <BlurFade
                  key={photo.src}
                  delay={BLUR_FADE_DELAY * 14 + (colIdx * col.length + idx) * 0.05}
                >
                  <img
                    src={withBase(photo.src)}
                    alt={photo.alt}
                    className={`w-full rounded-xl object-cover ${colAspects[colIdx][idx] ?? "aspect-square"}`}
                  />
                </BlurFade>
              ))}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
