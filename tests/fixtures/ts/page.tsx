import { cn } from "./cn";

type Props = {
  items: string[];
  open: boolean;
};

export class Store {
  private items: string[] = [];

  add(item: string): void {
    this.items.push(item);
  }
}

export default function Page({ items, open }: Props) {
  return (
    <main className="flex flex-col">
      <header
        className={cn(
          "sticky top-0",
          open && "shadow"
        )}
        role="banner"
      >
        <h1>Title</h1>
      </header>
      <Hero
        title="Hi"
        subtitle="There"
      />
      <ul>
        {items.map((item) => (
          <li key={item}>
            {item}
          </li>
        ))}
      </ul>
      {open && (
        <aside>
          <p>Open</p>
        </aside>
      )}
      <>
        <span>a</span>
        <span>b</span>
      </>
    </main>
  );
}

const Card = ({ title }: { title: string }) => (
  <div className="card">
    <h2>{title}</h2>
  </div>
);
