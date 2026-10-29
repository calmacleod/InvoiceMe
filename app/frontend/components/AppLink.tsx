import { Link, router } from "@inertiajs/react";
import type { ComponentProps, MouseEvent } from "react";
import { useRef } from "react";

type Props = ComponentProps<typeof Link> & { navigateOnMouseDown?: boolean };
const plainPrimary = (event: MouseEvent) =>
  event.button === 0 &&
  !event.metaKey &&
  !event.ctrlKey &&
  !event.shiftKey &&
  !event.altKey;

export default function AppLink({
  navigateOnMouseDown = false,
  onClick,
  onMouseDown,
  onPointerDown,
  onKeyDown,
  ...props
}: Props) {
  const pressed = useRef(false);
  return (
    <Link
      {...props}
      prefetch={props.method && props.method !== "get" ? false : "hover"}
      cacheFor="15s"
      onPrefetched={(response, visit) => {
        // Warm the lazy JavaScript chunk as well as the Inertia response.
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
              /* Navigation retries failed chunk loads. */
            });
          }
        }
        props.onPrefetched?.(response, visit);
      }}
      onPointerDown={(event) => {
        pressed.current = false;
        onPointerDown?.(event);
      }}
      onKeyDown={(event) => {
        pressed.current = false;
        onKeyDown?.(event);
      }}
      onMouseDown={(event) => {
        onMouseDown?.(event);
        if (
          navigateOnMouseDown &&
          !event.defaultPrevented &&
          plainPrimary(event) &&
          typeof props.href === "string"
        ) {
          pressed.current = true;
          router.visit(props.href);
        }
      }}
      onClick={(event) => {
        onClick?.(event);
        if (pressed.current && event.detail !== 0 && plainPrimary(event))
          event.preventDefault();
        pressed.current = false;
      }}
    />
  );
}
