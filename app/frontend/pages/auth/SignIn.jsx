import { Head, Link, useForm } from "@inertiajs/react";
import { Field, Errors } from "../../components/UI";

export default function SignIn() {
  const form = useForm({ email_address: "", password: "" });
  return (
    <div className="login-panel card">
      <Head title="Sign in" />
      <span className="eyebrow">EOTFOA TREASURER</span>
      <h1>Sign in</h1>
      <p>Your games, invoices, and records in one place.</p>
      <Errors errors={form.errors} />
      <form
        onSubmit={(event) => {
          event.preventDefault();
          form.post("/session", { onFinish: () => form.reset("password") });
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
        <button disabled={form.processing} className="button primary full">
          Sign in
        </button>
      </form>
      <p className="hint">
        <Link href="/passwords/new">Forgot password?</Link>
      </p>
    </div>
  );
}
