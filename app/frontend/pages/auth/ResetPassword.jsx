import { Head, useForm } from "@inertiajs/react";
import { Field, Errors } from "../../components/UI";

export default function ResetPassword({ token }) {
  const form = useForm({ password: "", password_confirmation: "" });
  return (
    <div className="login-panel card">
      <Head title="Update password" />
      <h1>Update your password</h1>
      <Errors errors={form.errors} />
      <form
        onSubmit={(event) => {
          event.preventDefault();
          form.put(`/passwords/${encodeURIComponent(token)}`, {
            onFinish: () => form.reset(),
          });
        }}
      >
        <Field
          name="password"
          label="New password"
          type="password"
          value={form.data.password}
          onChange={(value) => form.setData("password", value)}
          required
          maxLength={72}
          autoComplete="new-password"
        />
        <Field
          name="password_confirmation"
          label="Repeat new password"
          type="password"
          value={form.data.password_confirmation}
          onChange={(value) => form.setData("password_confirmation", value)}
          required
          maxLength={72}
          autoComplete="new-password"
        />
        <button className="button primary full" disabled={form.processing}>
          Save password
        </button>
      </form>
    </div>
  );
}
