import Link from "../../components/AppLink";
import * as stylex from "@stylexjs/stylex";
import { ui } from "../../styles/ui.stylex";
import { Head, useForm } from "@inertiajs/react";
import { Field, Errors } from "../../components/UI";
export default function ForgotPassword() {
  const form = useForm({
    email_address: "",
  });
  return (
    <div {...stylex.props(ui.card, ui.loginPanel)}>
      <Head title="Forgot password" />
      <h1 {...stylex.props(ui.h1)}>Forgot your password?</h1>
      <Errors errors={form.errors} />
      <form
        {...stylex.props(ui.formStack)}
        onSubmit={(event) => {
          event.preventDefault();
          form.post("/passwords");
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
        <button
          {...stylex.props(ui.nativeButton, ui.button, ui.primary, ui.full)}
          disabled={form.processing}
        >
          Email reset instructions
        </button>
      </form>
      <p {...stylex.props(ui.paragraph, ui.hint)}>
        <Link {...stylex.props(ui.link)} href="/session/new">
          Back to sign in
        </Link>
      </p>
    </div>
  );
}
