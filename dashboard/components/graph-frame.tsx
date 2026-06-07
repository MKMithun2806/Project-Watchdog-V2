'use client';

type GraphFrameProps = {
  srcDoc: string;
};

export function GraphFrame({ srcDoc }: GraphFrameProps) {
  return (
    <iframe
      className="w-full border-0 bg-bg"
      style={{ height: '100%', minHeight: '600px', display: 'block' }}
      srcDoc={srcDoc}
      title="Attack graph"
    />
  );
}
