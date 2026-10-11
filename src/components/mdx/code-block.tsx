import { useState, type ComponentProps } from "react";
import { Copy, Check } from "lucide-react";
import { Button } from "../ui/button";
import { cn } from "@/lib/utils";

type CodeBlockProps = ComponentProps<"pre"> & {
  "data-title"?: string;
};

export function CodeBlock({ children, ...props }: CodeBlockProps) {
  const [copied, setCopied] = useState(false);
  const title = props["data-title"];

  const handleCopy = async () => {
    const text =
      document.activeElement?.closest(".group")?.querySelector("code")?.textContent ?? "";
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // ignore
    }
  };

  return (
    <div className="group relative my-6 overflow-hidden rounded-xl border border-border">
      {title && (
        <div className="border-b border-border bg-muted/50 px-4 py-2 text-xs font-medium text-foreground">
          {title}
        </div>
      )}
      <Button
        onClick={handleCopy}
        variant="outline"
        size="icon"
        className={cn(
          "absolute right-3 size-8 cursor-pointer rounded-md border border-border text-primary opacity-100 shadow-none transition-opacity lg:opacity-0 lg:group-hover:opacity-100",
          title ? "top-13" : "top-3",
        )}
        aria-label="Copy code"
      >
        {copied ? <Check className="size-4" /> : <Copy className="size-4" />}
      </Button>
      <pre {...props} className={cn("m-0! overflow-x-auto p-4 text-sm", props.className)}>
        {children}
      </pre>
    </div>
  );
}
