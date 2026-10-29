import Link from "../../components/AppLink";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";
import { Head, useForm } from "@inertiajs/react";
import { Field, Errors } from "../../components/UI";
export default function SignIn() {
  const form = useForm({
    email_address: "",
    password: "",
  });
  return (
    <div {...stylex.props(ui.card, ui.loginPanel)}>
      <Head title="Sign in" />
      <span {...stylex.props(ui.eyebrow)}>EOTFOA TREASURER</span>
      <h1 {...stylex.props(ui.h1)}>Sign in</h1>
      <p {...stylex.props(ui.paragraph)}>
        Your games, invoices, and records in one place.
      </p>
      <Errors errors={form.errors} />
      <form
        {...stylex.props(ui.formStack)}
        onSubmit={(event) => {
          event.preventDefault();
          form.post("/session", {
            onFinish: () => form.reset("password"),
          });
        }}
      >
        <Field
          name="email_address"
          label="Email address"
          type="email"
          value={form.data.email_address}
          onChange={(value) => form.setData("email_address", value)}
          required
          autoFocus
          autoComplete="username"
        />
        <Field
          name="password"
          label="Password"
          type="password"
          value={form.data.password}
          onChange={(value) => form.setData("password", value)}
          required
          maxLength={72}
          autoComplete="current-password"
        />
        <button
          {...stylex.props(ui.nativeButton, ui.button, ui.primary, ui.full)}
          disabled={form.processing}
        >
          Sign in
        </button>
      </form>
      <p {...stylex.props(ui.paragraph, ui.hint)}>
        <Link {...stylex.props(ui.link)} href="/passwords/new">
          Forgot password?
        </Link>
      </p>
    </div>
  );
}
