import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import { supabase } from "./supabase";

export type AuthStatus = "loading" | "anon" | "member" | "admin";

interface AuthState {
  status: AuthStatus;
  userId: string | null;
  displayName: string | null;
  signIn: (email: string, password: string) => Promise<string | null>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthState>({
  status: "loading",
  userId: null,
  displayName: null,
  signIn: async () => null,
  signOut: async () => {},
});

interface ProfileRow {
  display_name: string | null;
  is_admin: boolean | null;
}

async function resolveProfile(userId: string): Promise<{
  status: AuthStatus;
  displayName: string | null;
}> {
  const { data, error } = await supabase
    .from("profiles")
    .select("display_name, is_admin")
    .eq("id", userId)
    .maybeSingle<ProfileRow>();
  if (error) {
    // A suspended (RLS-blocked) profile looks identical to a missing one.
    return { status: "member", displayName: null };
  }
  if (!data) return { status: "member", displayName: null };
  return { status: data.is_admin ? "admin" : "member", displayName: data.display_name };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<AuthStatus>("loading");
  const [userId, setUserId] = useState<string | null>(null);
  const [displayName, setDisplayName] = useState<string | null>(null);

  const resolve = useCallback(async (uid: string | null) => {
    if (!uid) {
      setUserId(null);
      setDisplayName(null);
      setStatus("anon");
      return;
    }
    setUserId(uid);
    const { status: s, displayName: name } = await resolveProfile(uid);
    setDisplayName(name);
    setStatus(s);
  }, []);

  useEffect(() => {
    void (async () => {
      const { data } = await supabase.auth.getSession();
      await resolve(data.session?.user?.id ?? null);
    })();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      void resolve(session?.user?.id ?? null);
    });
    return () => subscription.unsubscribe();
  }, [resolve]);

  const signIn = useCallback(
    async (email: string, password: string): Promise<string | null> => {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      });
      if (error) return error.message;
      const user = data.session?.user?.id ?? null;
      if (!user) return "Signed in but no session was returned.";
      const resolved = await resolveProfile(user);
      if (resolved.status === "admin") {
        setUserId(user);
        setDisplayName(resolved.displayName);
        setStatus("admin");
        return null;
      }
      await supabase.auth.signOut();
      return "This account does not have admin access.";
    },
    [],
  );

  const signOut = useCallback(async () => {
    await supabase.auth.signOut();
    setUserId(null);
    setDisplayName(null);
    setStatus("anon");
  }, []);

  return (
    <AuthContext.Provider value={{ status, userId, displayName, signIn, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthState {
  return useContext(AuthContext);
}
