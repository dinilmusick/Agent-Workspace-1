import type { BrowserToolchainSource, ServerToolchainSource, ToolchainDescriptor } from "@wasm-oj/contracts";

export declare const descriptor: ToolchainDescriptor & { readonly id: "go"; readonly version: "1.26.5" };
export declare function browserSource(baseUrl: string): BrowserToolchainSource;
export declare function serverSource(): ServerToolchainSource;
