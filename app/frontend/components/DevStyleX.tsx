import { useEffect, useRef } from "react";

function DevelopmentStyles() {
  const link = useRef<HTMLLinkElement>(null);
  const cssUrl = new URL(
    /* @vite-ignore */ "/virtual:stylex.css",
    import.meta.url,
  ).href;
  useEffect(() => {
    // The linked stylesheet belongs to Vite, rather than the Rails page origin.
    const refresh = () => {
      if (link.current) link.current.href = `${cssUrl}?t=${Date.now()}`;
    };
    import.meta.hot?.on("stylex:css-update", refresh);
    import.meta.hot?.on("vite:afterUpdate", refresh);
    return () => {
      import.meta.hot?.off("stylex:css-update", refresh);
      import.meta.hot?.off("vite:afterUpdate", refresh);
    };
  }, [cssUrl]);
  return <link ref={link} rel="stylesheet" href={cssUrl} />;
}

export default function DevStyleX() {
  return import.meta.env.DEV ? <DevelopmentStyles /> : null;
}
