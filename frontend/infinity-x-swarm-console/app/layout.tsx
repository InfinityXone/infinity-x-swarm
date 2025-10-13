export const metadata = {
  title: "Infinity X Swarm – Console",
  description: "Cloud Run faucet HQ + Satellites control surface",
};
import "./globals.css";
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="bg-[#0b0b0d] text-white antialiased selection:bg-[#39ff14]/30 selection:text-white">
        {children}
      </body>
    </html>
  );
}
