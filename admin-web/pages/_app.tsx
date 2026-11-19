import type { AppProps } from "next/app";
import { Nunito } from "next/font/google";
import "@/styles/globals.css";
import { LanguageProvider } from "@/lib/language-context";

const nunito = Nunito({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
  variable: "--font-nunito",
  display: "swap",
});

export default function App({ Component, pageProps }: AppProps) {
  return (
    <LanguageProvider>
      <div className={`${nunito.variable} font-sans min-h-screen antialiased text-[#102737]`}>
        <Component {...pageProps} />
      </div>
    </LanguageProvider>
  );
}
