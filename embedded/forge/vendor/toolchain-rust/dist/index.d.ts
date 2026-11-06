import type { BrowserToolchainSource, ServerToolchainSource, ToolchainDescriptor } from "@wasm-oj/contracts";

export declare const descriptor: ToolchainDescriptor & { readonly id: "rust"; readonly version: "1.91.1-dev" };
export declare function browserSource(baseUrl: string): BrowserToolchainSource;
export declare function serverSource(): ServerToolchainSource;
