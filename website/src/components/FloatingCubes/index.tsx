import type {ReactNode} from 'react';
import styles from './styles.module.css';

// Cube configuration type
type CubeConfig = {
  id: string;
  name: string;
  size: 'small' | 'medium';
  position: { x: number; y: number };
  delay: number;
};

// Cubes inside the cloud (running services) - pyramid arrangement
const runningCubes: CubeConfig[] = [
  // Bottom row of pyramid
  { id: 'k8s', name: 'Kubernetes', size: 'medium', position: { x: 20, y: 42 }, delay: 0 },
  { id: 'postgres', name: 'PostgreSQL', size: 'medium', position: { x: 40, y: 42 }, delay: 0.2 },
  { id: 'redis', name: 'Redis', size: 'medium', position: { x: 60, y: 42 }, delay: 0.4 },
  // Middle row
  { id: 'grafana', name: 'Grafana', size: 'medium', position: { x: 30, y: 24 }, delay: 0.6 },
  { id: 'prometheus', name: 'Prometheus', size: 'medium', position: { x: 50, y: 24 }, delay: 0.8 },
  // Top - this one will be swapped out
  // (empty slot - the exiting cube animates from here)
];

// Cubes below the cloud (waiting services) - horizontal row
const waitingCubes: CubeConfig[] = [
  { id: 'nginx', name: 'Nginx', size: 'small', position: { x: 15, y: 88 }, delay: 0 },
  { id: 'traefik', name: 'Traefik', size: 'small', position: { x: 30, y: 88 }, delay: 0.3 },
  { id: 'loki', name: 'Loki', size: 'small', position: { x: 45, y: 88 }, delay: 0.6 },
  { id: 'tempo', name: 'Tempo', size: 'small', position: { x: 60, y: 88 }, delay: 0.9 },
  { id: 'minio', name: 'Minio', size: 'small', position: { x: 75, y: 88 }, delay: 1.2 },
];

type IsometricCubeProps = {
  name: string;
  size: 'small' | 'medium';
  style?: React.CSSProperties;
  delay: number;
  variant: 'running' | 'waiting';
};

function IsometricCube({ name, size, style, delay, variant }: IsometricCubeProps): ReactNode {
  const sizeClass = size === 'small' ? styles.cubeSmall : styles.cubeMedium;
  const variantClass = variant === 'running' ? styles.runningCube : styles.waitingCube;
  const label = name.substring(0, 3).toUpperCase();

  return (
    <div
      className={`${styles.cubeWrapper} ${sizeClass} ${variantClass}`}
      style={{ ...style, animationDelay: `${delay}s` }}
    >
      <div className={styles.cube} style={{ animationDelay: `${delay}s` }}>
        <div className={`${styles.face} ${styles.faceTop}`}>
          <span className={styles.faceLabel}>{label}</span>
        </div>
        <div className={`${styles.face} ${styles.faceFront}`}>
          <span className={styles.faceLabel}>{label}</span>
        </div>
        <div className={`${styles.face} ${styles.faceBack}`}>
          <span className={styles.faceLabel}>{label}</span>
        </div>
        <div className={`${styles.face} ${styles.faceLeft}`}>
          <span className={styles.faceLabel}>{label}</span>
        </div>
        <div className={`${styles.face} ${styles.faceRight}`}>
          <span className={styles.faceLabel}>{label}</span>
        </div>
      </div>
    </div>
  );
}

type FloatingCubesProps = {
  className?: string;
};

export default function FloatingCubes({ className }: FloatingCubesProps): ReactNode {
  return (
    <div className={`${styles.scene} ${className || ''}`}>
      {/* Cloud SVG background - positioned in upper area */}
      <svg
        className={styles.cloudSvg}
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 100 80"
        preserveAspectRatio="xMidYMid meet"
      >
        <path
          d="M78 56
             C85 56, 90 50, 90 42
             C90 34, 84 28, 76 28
             C75 17, 65 9, 50 9
             C37 9, 27 17, 26 28
             C24 27, 21 26, 18 26
             C9 26, 2 34, 2 44
             C2 54, 9 62, 20 62
             L76 62
             C83 62, 88 58, 88 52
             Z"
          fill="none"
          stroke="#3a8f5e"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          className={styles.cloudPath}
        />
      </svg>

      {/* Empty slot indicator at top of pyramid */}
      <div className={styles.emptySlot} />

      {/* Running cubes inside cloud (pyramid) */}
      {runningCubes.map((cube) => (
        <IsometricCube
          key={cube.id}
          name={cube.name}
          size={cube.size}
          delay={cube.delay}
          variant="running"
          style={{
            left: `${cube.position.x}%`,
            top: `${cube.position.y}%`,
          }}
        />
      ))}

      {/* Cube exiting cloud (animates down and out) */}
      <div className={styles.exitingCube}>
        <div className={`${styles.cubeWrapper} ${styles.cubeMedium}`}>
          <div className={styles.cube}>
            <div className={`${styles.face} ${styles.faceTop}`}>
              <span className={styles.faceLabel}>OLL</span>
            </div>
            <div className={`${styles.face} ${styles.faceFront}`}>
              <span className={styles.faceLabel}>OLL</span>
            </div>
            <div className={`${styles.face} ${styles.faceBack}`}>
              <span className={styles.faceLabel}>OLL</span>
            </div>
            <div className={`${styles.face} ${styles.faceLeft}`}>
              <span className={styles.faceLabel}>OLL</span>
            </div>
            <div className={`${styles.face} ${styles.faceRight}`}>
              <span className={styles.faceLabel}>OLL</span>
            </div>
          </div>
        </div>
      </div>

      {/* Cube entering cloud (animates up into slot) */}
      <div className={styles.enteringCube}>
        <div className={`${styles.cubeWrapper} ${styles.cubeMedium}`}>
          <div className={styles.cube}>
            <div className={`${styles.face} ${styles.faceTop} ${styles.faceEntering}`}>
              <span className={styles.faceLabel}>AI</span>
            </div>
            <div className={`${styles.face} ${styles.faceFront} ${styles.faceEntering}`}>
              <span className={styles.faceLabel}>AI</span>
            </div>
            <div className={`${styles.face} ${styles.faceBack} ${styles.faceEntering}`}>
              <span className={styles.faceLabel}>AI</span>
            </div>
            <div className={`${styles.face} ${styles.faceLeft} ${styles.faceEntering}`}>
              <span className={styles.faceLabel}>AI</span>
            </div>
            <div className={`${styles.face} ${styles.faceRight} ${styles.faceEntering}`}>
              <span className={styles.faceLabel}>AI</span>
            </div>
          </div>
        </div>
      </div>

      {/* Waiting cubes below cloud (horizontal row) */}
      {waitingCubes.map((cube) => (
        <IsometricCube
          key={cube.id}
          name={cube.name}
          size={cube.size}
          delay={cube.delay}
          variant="waiting"
          style={{
            left: `${cube.position.x}%`,
            top: `${cube.position.y}%`,
          }}
        />
      ))}
    </div>
  );
}
