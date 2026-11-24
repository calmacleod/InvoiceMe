import { Link, router } from "@inertiajs/react";
import type { ComponentProps } from "react";

export default function AppLink(props: ComponentProps<typeof Link>) {
  return (
    <Link
      prefetch={props.method && props.method !== "get" ? false : "hover"}
      cacheFor="15s"
      {...props}
      onPrefetched={(response, visit) => {
        if (response.headers["x-inertia"]) {
          const page: unknown =
            typeof response.data === "string"
              ? JSON.parse(response.data)
              : response.data;
          if (
            page &&
            typeof page === "object" &&
            "component" in page &&
            typeof page.component === "string"
          ) {
            void router.resolveComponent(page.component).catch(() => {
              /* The visit retries failed chunk loads. */
            });
          }
        }
        props.onPrefetched?.(response, visit);
      }}
    />
  );
}
