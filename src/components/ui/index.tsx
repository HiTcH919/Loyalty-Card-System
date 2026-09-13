// Shared UI primitives.
import * as React from "react";
import { cn } from "@/lib/utils";

type ButtonVariant = "default" | "secondary" | "outline" | "ghost" | "destructive" | "link";
type ButtonSize = "default" | "sm" | "lg" | "icon";

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  isLoading?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = "default", size = "default", isLoading = false, disabled, children, ...props }, ref) => {
    const baseStyles = "inline-flex items-center justify-center gap-2 whitespace-nowrap font-medium transition-all duration-150 rounded-lg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 active:scale-[0.98]";
    const variants = {
      default: "bg-primary text-primary-foreground hover:bg-primary/90 shadow-sm",
      secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/80",
      outline: "border border-border bg-transparent hover:bg-accent hover:text-accent-foreground",
      ghost: "hover:bg-accent hover:text-accent-foreground",
      destructive: "bg-destructive text-destructive-foreground hover:bg-destructive/90",
      link: "text-primary underline-offset-4 hover:underline",
    };
    const sizes = {
      default: "h-10 px-4 py-2 text-sm",
      sm: "h-8 rounded-md px-3 text-xs",
      lg: "h-12 rounded-lg px-8 text-base",
      icon: "h-10 w-10",
    };
    return (
      <button className={cn(baseStyles, variants[variant], sizes[size], className)} ref={ref} disabled={disabled || isLoading} {...props}>
        {isLoading ? (
          <>
            <svg className="animate-spin -ml-1 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" />
            </svg>
            <span>Loading...</span>
          </>
        ) : children}
      </button>
    );
  }
);
Button.displayName = "Button";

export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {}
const Card = React.forwardRef<HTMLDivElement, CardProps>(({ className, ...props }, ref) => (
  <div ref={ref} className={cn("rounded-xl border border-border bg-card text-card-foreground shadow-sm", className)} {...props} />
));
Card.displayName = "Card";
const CardHeader = React.forwardRef<HTMLDivElement, CardProps>(({ className, ...props }, ref) => (
  <div ref={ref} className={cn("flex flex-col space-y-1.5 p-6", className)} {...props} />
));
CardHeader.displayName = "CardHeader";
const CardTitle = React.forwardRef<HTMLHeadingElement, React.HTMLAttributes<HTMLHeadingElement>>(({ className, ...props }, ref) => (
  <h3 ref={ref} className={cn("text-xl font-semibold leading-none tracking-tight", className)} {...props} />
));
CardTitle.displayName = "CardTitle";
const CardDescription = React.forwardRef<HTMLParagraphElement, React.HTMLAttributes<HTMLParagraphElement>>(({ className, ...props }, ref) => (
  <p ref={ref} className={cn("text-sm text-muted-foreground", className)} {...props} />
));
CardDescription.displayName = "CardDescription";
const CardContent = React.forwardRef<HTMLDivElement, CardProps>(({ className, ...props }, ref) => (
  <div ref={ref} className={cn("p-6 pt-0", className)} {...props} />
));
CardContent.displayName = "CardContent";
const CardFooter = React.forwardRef<HTMLDivElement, CardProps>(({ className, ...props }, ref) => (
  <div ref={ref} className={cn("flex items-center p-6 pt-0", className)} {...props} />
));
CardFooter.displayName = "CardFooter";

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  hint?: string;
}
const Input = React.forwardRef<HTMLInputElement, InputProps>(({ className, type, label, error, hint, id, ...props }, ref) => {
  const inputId = id ?? React.useId();
  return (
    <div className="space-y-2">
      {label && <label htmlFor={inputId} className="text-sm font-medium text-foreground">{label}</label>}
      <input type={type} id={inputId} className={cn("flex h-10 w-full rounded-lg border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50", error && "border-destructive focus-visible:ring-destructive", className)} ref={ref} {...props} />
      {error && <p className="text-sm text-destructive">{error}</p>}
      {hint && !error && <p className="text-sm text-muted-foreground">{hint}</p>}
    </div>
  );
});
Input.displayName = "Input";

export interface TextareaProps extends React.TextareaHTMLAttributes<HTMLTextAreaElement> {
  label?: string;
  error?: string;
  hint?: string;
}
const Textarea = React.forwardRef<HTMLTextAreaElement, TextareaProps>(({ className, label, error, hint, id, ...props }, ref) => {
  const inputId = id ?? React.useId();
  return (
    <div className="space-y-2">
      {label && <label htmlFor={inputId} className="text-sm font-medium text-foreground">{label}</label>}
      <textarea id={inputId} className={cn("flex min-h-[80px] w-full rounded-lg border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50", error && "border-destructive focus-visible:ring-destructive", className)} ref={ref} {...props} />
      {error && <p className="text-sm text-destructive">{error}</p>}
      {hint && !error && <p className="text-sm text-muted-foreground">{hint}</p>}
    </div>
  );
});
Textarea.displayName = "Textarea";

export interface SelectProps extends React.SelectHTMLAttributes<HTMLSelectElement> {
  label?: string;
  error?: string;
  options: { value: string; label: string }[];
  placeholder?: string;
}
const Select = React.forwardRef<HTMLSelectElement, SelectProps>(({ className, label, error, options, placeholder, id, ...props }, ref) => {
  const inputId = id ?? React.useId();
  return (
    <div className="space-y-2">
      {label && <label htmlFor={inputId} className="text-sm font-medium text-foreground">{label}</label>}
      <select id={inputId} className={cn("flex h-10 w-full rounded-lg border border-input bg-background px-3 py-2 text-sm ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50", error && "border-destructive focus-visible:ring-destructive", className)} ref={ref} {...props}>
        {placeholder && <option value="" disabled>{placeholder}</option>}
        {options.map((opt) => <option key={opt.value} value={opt.value}>{opt.label}</option>)}
      </select>
      {error && <p className="text-sm text-destructive">{error}</p>}
    </div>
  );
});
Select.displayName = "Select";

export interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  variant?: "default" | "secondary" | "destructive" | "outline" | "success" | "warning";
}
const Badge = React.forwardRef<HTMLSpanElement, BadgeProps>(({ className, variant = "default", ...props }, ref) => {
  const variants = {
    default: "bg-primary text-primary-foreground",
    secondary: "bg-secondary text-secondary-foreground",
    destructive: "bg-destructive text-destructive-foreground",
    outline: "border border-current text-foreground",
    success: "bg-emerald-100 text-emerald-800 dark:bg-emerald-900 dark:text-emerald-100",
    warning: "bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-100",
  };
  return <span ref={ref} className={cn("inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold transition-colors", variants[variant], className)} {...props} />;
});
Badge.displayName = "Badge";

export interface AvatarProps extends React.HTMLAttributes<HTMLDivElement> {
  src?: string | null;
  alt?: string;
  size?: "sm" | "md" | "lg";
  fallback?: string;
}
const Avatar = React.forwardRef<HTMLDivElement, AvatarProps>(({ className, src, alt, size = "md", fallback, ...props }, ref) => {
  const sizes = { sm: "h-8 w-8 text-xs", md: "h-10 w-10 text-sm", lg: "h-12 w-12 text-base" };
  const [imageError, setImageError] = React.useState(false);
  const showFallback = !src || imageError;
  return (
    <div ref={ref} className={cn("relative flex shrink-0 overflow-hidden rounded-full", sizes[size], className)} {...props}>
      {showFallback ? (
        <div className="flex h-full w-full items-center justify-center rounded-full bg-muted">
          {fallback ? <span className="font-medium text-muted-foreground">{fallback}</span> : <span className="text-muted-foreground">?</span>}
        </div>
      ) : (
        <img src={src} alt={alt ?? fallback ?? ""} className="aspect-square h-full w-full object-cover" onError={() => setImageError(true)} />
      )}
    </div>
  );
});
Avatar.displayName = "Avatar";

export interface AvatarGroupProps extends React.HTMLAttributes<HTMLDivElement> {
  avatars: { src?: string | null; alt?: string; fallback?: string }[];
  max?: number;
  size?: "sm" | "md" | "lg";
}
const AvatarGroup = React.forwardRef<HTMLDivElement, AvatarGroupProps>(({ className, avatars, max = 4, size = "md", ...props }, ref) => {
  const visible = avatars.slice(0, max);
  const remaining = avatars.length - max;
  return (
    <div ref={ref} className={cn("flex -space-x-2", className)} {...props}>
      {visible.map((avatar, i) => <Avatar key={i} src={avatar.src} alt={avatar.alt} fallback={avatar.fallback} size={size} className="ring-2 ring-background" />)}
      {remaining > 0 && <div className={cn("flex h-10 w-10 items-center justify-center rounded-full bg-muted text-xs font-medium text-muted-foreground ring-2 ring-background", size === "sm" && "h-8 w-8 text-xs", size === "lg" && "h-12 w-12 text-base")}>+{remaining}</div>}
    </div>
  );
});
AvatarGroup.displayName = "AvatarGroup";

const Separator = React.forwardRef<HTMLHRElement, React.HTMLAttributes<HTMLHRElement>>(({ className, ...props }, ref) => (
  <hr ref={ref} className={cn("border-border", className)} {...props} />
));
Separator.displayName = "Separator";

const Skeleton = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(({ className, ...props }, ref) => (
  <div ref={ref} className={cn("animate-pulse rounded-md bg-muted", className)} {...props} />
));
Skeleton.displayName = "Skeleton";

export interface EmptyStateProps {
  title: string;
  description?: string;
  action?: React.ReactNode;
  icon?: React.ReactNode;
  className?: string;
}
export function EmptyState({ title, description, action, icon, className }: EmptyStateProps) {
  return (
    <div className={cn("flex flex-col items-center justify-center text-center space-y-3 py-12", className)}>
      {icon && <div className="text-muted-foreground">{icon}</div>}
      <div className="space-y-1">
        <h3 className="text-lg font-semibold text-foreground">{title}</h3>
        {description && <p className="text-sm text-muted-foreground">{description}</p>}
      </div>
      {action && <div>{action}</div>}
    </div>
  );
}

export interface TableProps extends React.HTMLAttributes<HTMLTableElement> {}
const Table = React.forwardRef<HTMLTableElement, TableProps>(({ className, ...props }, ref) => (
  <div className="relative w-full overflow-auto"><table ref={ref} className={cn("w-full caption-bottom text-sm", className)} {...props} /></div>
));
Table.displayName = "Table";

export interface TableHeader<T extends string> extends React.HTMLAttributes<HTMLTableSectionElement> {
  columns: { id: T; label: string }[];
}
export function TableHeaderWrapper<T extends string>({ columns, className, ...props }: TableHeader<T> & { children?: React.ReactNode }) {
  return <thead className={cn("border-b", className)} {...props}><tr className="border-border">{columns.map((col) => <th key={col.id} className="h-12 px-4 text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground" scope="col">{col.label}</th>)}</tr></thead>;
}

export interface TableBodyProps extends React.HTMLAttributes<HTMLTableSectionElement> {
  children: React.ReactNode;
}
const TableBody = React.forwardRef<HTMLTableSectionElement, TableBodyProps>(({ className, children, ...props }, ref) => (
  <tbody ref={ref} className={cn("border-border divide-y divide-border", className)} {...props}>{children}</tbody>
));
TableBody.displayName = "TableBody";

export interface TableRowProps extends React.HTMLAttributes<HTMLTableRowElement> {
  children: React.ReactNode;
}
const TableRow = React.forwardRef<HTMLTableRowElement, TableRowProps>(({ className, children, ...props }, ref) => (
  <tr ref={ref} className={cn("hover:bg-muted/50 transition-colors", className)} {...props}>{children}</tr>
));
TableRow.displayName = "TableRow";

export interface TableCellProps extends React.HTMLAttributes<HTMLTableCellElement> {
  children: React.ReactNode;
}
const TableCell = React.forwardRef<HTMLTableCellElement, TableCellProps>(({ className, children, ...props }, ref) => (
  <td ref={ref} className={cn("p-4 align-middle", className)} {...props}>{children}</td>
));
TableCell.displayName = "TableCell";
