import { BrowserRouter, Route, Routes } from "react-router-dom";
import { RequireAdmin } from "@/components/RequireAdmin";
import { AppShell } from "@/components/AppShell";
import { LoginPage } from "@/pages/LoginPage";
import { DashboardPage } from "@/pages/DashboardPage";
import { UsersPage } from "@/pages/UsersPage";
import { UserDetailPage } from "@/pages/UserDetailPage";
import { CribsPage } from "@/pages/CribsPage";
import { CribDetailPage } from "@/pages/CribDetailPage";
import { ExpensesPage } from "@/pages/ExpensesPage";
import { DisputesPage } from "@/pages/DisputesPage";
import { SettlementsPage } from "@/pages/SettlementsPage";
import { RecurringPage } from "@/pages/RecurringPage";
import { ActivityPage } from "@/pages/ActivityPage";
import { AuditPage } from "@/pages/AuditPage";

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route element={<RequireAdmin />}>
          <Route element={<AppShell />}>
            <Route index element={<DashboardPage />} />
            <Route path="/users" element={<UsersPage />} />
            <Route path="/users/:id" element={<UserDetailPage />} />
            <Route path="/cribs" element={<CribsPage />} />
            <Route path="/cribs/:id" element={<CribDetailPage />} />
            <Route path="/expenses" element={<ExpensesPage />} />
            <Route path="/disputes" element={<DisputesPage />} />
            <Route path="/settlements" element={<SettlementsPage />} />
            <Route path="/recurring" element={<RecurringPage />} />
            <Route path="/activity" element={<ActivityPage />} />
            <Route path="/audit" element={<AuditPage />} />
          </Route>
        </Route>
        <Route path="*" element={<LoginPage />} />
      </Routes>
    </BrowserRouter>
  );
}
