import type { Code, Root } from "mdast";

type CodeWithData = Code & {
  data?: { hProperties?: Record<string, string> };
};

type Node = { type: string; children?: Node[] };

export function remarkCodeMeta() {
  return (tree: Root) => {
    const walk = (node: Node) => {
      if (!node || typeof node !== "object") return;

      if (node.type === "code") {
        const code = node as CodeWithData;
        const meta = code.meta ?? undefined;
        if (meta) {
          code.data ||= {};
          code.data.hProperties ||= {};

          code.data.hProperties["data-meta"] = meta;

          const titleMatch = meta.match(/title="([^"]+)"/);
          if (titleMatch?.[1]) {
            code.data.hProperties["data-title"] = titleMatch[1];
          }
        }
      }

      const children = node.children;
      if (Array.isArray(children)) {
        for (const child of children) walk(child);
      }
    };

    walk(tree);
  };
}
