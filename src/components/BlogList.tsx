import BlurFade from "@/components/magicui/blur-fade";
import { ChevronRight } from "lucide-react";

const BLUR_FADE_DELAY = 0.04;

interface Post {
  id: string;
  title: string;
  publishedAt: string;
}

interface Pagination {
  page: number;
  totalPages: number;
  prevUrl?: string;
  nextUrl?: string;
}

interface BlogListProps {
  posts: Post[];
  allPostsCount: number;
  pagination: Pagination;
  pageSize: number;
  description: string;
}

export default function BlogList({
  posts,
  allPostsCount,
  pagination,
  pageSize,
  description,
}: BlogListProps) {
  return (
    <section id="blog">
      <BlurFade delay={BLUR_FADE_DELAY}>
        <h1 className="mb-4 text-2xl font-semibold tracking-tight">
          Blog{" "}
          <span className="ml-1 rounded-md border border-border bg-card px-2 py-1 text-sm text-muted-foreground">
            {allPostsCount} posts
          </span>
        </h1>
        <p className="mb-8 text-sm text-muted-foreground">{description}</p>
      </BlurFade>

      {posts.length > 0 ? (
        <>
          <BlurFade delay={BLUR_FADE_DELAY * 2}>
            <div className="flex flex-col gap-5">
              {posts.map((post, id) => {
                const indexNumber = (pagination.page - 1) * pageSize + id + 1;
                return (
                  <BlurFade delay={BLUR_FADE_DELAY * 3 + id * 0.05} key={post.id}>
                    <a
                      className="group flex cursor-pointer items-start gap-x-2 focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:outline-none"
                      href={`/blog/${post.id}`}
                    >
                      <span className="mt-[5px] font-mono text-xs font-medium tabular-nums">
                        {String(indexNumber).padStart(2, "0")}.
                      </span>
                      <div className="flex flex-1 flex-col gap-y-2">
                        <p className="text-lg font-medium tracking-tight">
                          <span className="transition-colors group-hover:text-foreground">
                            {post.title}
                            <ChevronRight
                              className="ml-1 inline-block size-4 -translate-x-2 stroke-3 text-muted-foreground opacity-0 transition-all duration-200 group-hover:translate-x-0 group-hover:opacity-100"
                              aria-hidden
                            />
                          </span>
                        </p>
                        <p className="text-xs text-muted-foreground">{post.publishedAt}</p>
                      </div>
                    </a>
                  </BlurFade>
                );
              })}
            </div>
          </BlurFade>

          {pagination.totalPages > 1 && (
            <BlurFade delay={BLUR_FADE_DELAY * 4}>
              <div className="mt-8 flex flex-row items-center justify-between gap-3">
                <div className="text-sm text-muted-foreground">
                  Page {pagination.page} of {pagination.totalPages}
                </div>
                <div className="flex gap-2 sm:justify-end">
                  {pagination.prevUrl ? (
                    <a
                      href={pagination.prevUrl}
                      className="flex h-8 w-fit items-center justify-center rounded-lg border border-border px-2 text-sm transition-colors hover:bg-accent/50 focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:outline-none"
                    >
                      Previous
                    </a>
                  ) : (
                    <span className="flex h-8 w-fit cursor-not-allowed items-center justify-center rounded-lg border border-border px-2 text-sm opacity-50">
                      Previous
                    </span>
                  )}
                  {pagination.nextUrl ? (
                    <a
                      href={pagination.nextUrl}
                      className="flex h-8 w-fit items-center justify-center rounded-lg border border-border px-2 text-sm transition-colors hover:bg-accent/50 focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:outline-none"
                    >
                      Next
                    </a>
                  ) : (
                    <span className="flex h-8 w-fit cursor-not-allowed items-center justify-center rounded-lg border border-border px-2 text-sm opacity-50">
                      Next
                    </span>
                  )}
                </div>
              </div>
            </BlurFade>
          )}
        </>
      ) : (
        <BlurFade delay={BLUR_FADE_DELAY * 2}>
          <div className="flex flex-col items-center justify-center rounded-xl border border-border px-4 py-12">
            <p className="text-center text-muted-foreground">No blog posts yet. Check back soon!</p>
          </div>
        </BlurFade>
      )}
    </section>
  );
}
