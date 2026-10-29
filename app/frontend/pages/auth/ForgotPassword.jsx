import { Head, Link, useForm } from "@inertiajs/react";
import { Field, Errors } from "../../components/UI";

export default function ForgotPassword() {
  const form = useForm({ email_address: "" });
  return (
    <div className="login-panel card">
      <Head title="Forgot password" />
      <h1>Forgot your password?</h1>
      <Errors errors={form.errors} />
      <form
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
        <button className="button primary full" disabled={form.processing}>
          Email reset instructions
        </button>
      </form>
      <p className="hint">
        <Link href="/session/new">Back to sign in</Link>
      </p>
    </div>
  );
}
